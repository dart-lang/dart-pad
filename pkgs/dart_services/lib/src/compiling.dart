// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/driver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'project_templates.dart';
import 'pub.dart';
import 'sdk.dart';

final Logger _logger = Logger('compiler');

/// An interface to the dart2js compiler. A compiler object can process one
/// compile at a time.
class Compiler {
  final Sdk _sdk;
  final String _dartPath;
  final BazelWorkerDriver _ddcDriver;
  final String _storageBucket;

  final ProjectTemplates _projectTemplates;

  Compiler(
    Sdk sdk, {
    required String storageBucket,
  }) : this._(sdk, path.join(sdk.dartSdkPath, 'bin', 'dart'), storageBucket);

  Compiler._(this._sdk, this._dartPath, this._storageBucket)
      : _ddcDriver = BazelWorkerDriver(
            () => Process.start(_dartPath, [
                  path.join(_sdk.dartSdkPath, 'bin', 'snapshots',
                      'dartdevc.dart.snapshot'),
                  '--persistent_worker'
                ]),
            maxWorkers: 1),
        _projectTemplates = ProjectTemplates.projectTemplates;

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(
    String source, {
    bool returnSourceMap = false,
  }) async {
    final temp = Directory.systemTemp.createTempSync('dartpad');
    _logger.fine('Temp directory created: ${temp.path}');

    try {
      _copyPath(_projectTemplates.dartPath, temp.path);
      Directory(path.join(temp.path, 'lib')).createSync(recursive: true);

      final arguments = <String>[
        'compile',
        'js',
        '--suppress-hints',
        '--terse',
        if (!returnSourceMap) '--no-source-maps',
        '--packages=${path.join('.dart_tool', 'package_config.json')}',
        '--enable-asserts',
        if (_sdk.experiments.isNotEmpty)
          '--enable-experiment=${_sdk.experiments.join(",")}',
        '-o',
        '$kMainDart.js',
        path.join('lib', kMainDart),
      ];

      File(path.join(temp.path, 'lib', kMainDart)).writeAsStringSync(source);

      final mainJs = File(path.join(temp.path, '$kMainDart.js'));
      final mainSourceMap = File(path.join(temp.path, '$kMainDart.js.map'));

      _logger.fine('About to exec: $_dartPath ${arguments.join(' ')}');

      final result =
          await Process.run(_dartPath, arguments, workingDirectory: temp.path);

      if (result.exitCode != 0) {
        final results = CompilationResults(problems: <CompilationProblem>[
          CompilationProblem._(result.stdout as String),
        ]);
        return results;
      } else {
        String? sourceMap;
        if (returnSourceMap && mainSourceMap.existsSync()) {
          sourceMap = mainSourceMap.readAsStringSync();
        }
        final results = CompilationResults(
          compiledJS: mainJs.readAsStringSync(),
          sourceMap: sourceMap,
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      temp.deleteSync(recursive: true);
      _logger.fine('temp folder removed: ${temp.path}');
    }
  }

  /// Compile the given string and return the resulting [DDCCompilationResults].
  Future<DDCCompilationResults> compileDDC(String source) async {
    final imports = getAllImportsFor(source);

    final temp = Directory.systemTemp.createTempSync('dartpad');
    _logger.fine('Temp directory created: ${temp.path}');

    try {
      final usingFlutter = usesFlutterWeb(imports);
      if (usingFlutter) {
        _copyPath(_projectTemplates.flutterPath, temp.path);
      } else {
        _copyPath(_projectTemplates.dartPath, temp.path);
      }

      Directory(path.join(temp.path, 'lib')).createSync(recursive: true);

      final bootstrapPath = path.join(temp.path, 'lib', kBootstrapDart);
      String bootstrapContents;
      if (usingFlutter) {
        bootstrapContents = _sdk.usesNewBootstrapEngine
            ? kBootstrapFlutterCode
            : kBootstrapFlutterCode_3_16;
      } else {
        bootstrapContents = kBootstrapDartCode;
      }

      File(bootstrapPath).writeAsStringSync(bootstrapContents);
      File(path.join(temp.path, 'lib', kMainDart)).writeAsStringSync(source);

      final arguments = <String>[
        '--modules=amd',
        '--no-summarize',
        if (usingFlutter) ...[
          '-s',
          _projectTemplates.summaryFilePath,
          '-s',
          '${_sdk.flutterWebSdkPath}/ddc_outline_sound.dill',
        ],
        ...['-o', path.join(temp.path, '$kMainDart.js')],
        ...['--module-name', 'dartpad_main'],
        '--enable-asserts',
        if (_sdk.experiments.isNotEmpty)
          '--enable-experiment=${_sdk.experiments.join(",")}',
        bootstrapPath,
        '--packages=${path.join(temp.path, '.dart_tool', 'package_config.json')}',
      ];

      final mainJs = File(path.join(temp.path, '$kMainDart.js'));

      _logger.fine('About to exec dartdevc worker: ${arguments.join(' ')}"');

      final response =
          await _ddcDriver.doWork(WorkRequest(arguments: arguments));

      if (response.exitCode != 0) {
        return DDCCompilationResults.failed([
          CompilationProblem._(_rewritePaths(response.output)),
        ]);
      } else {
        // The `--single-out-file` option for dartdevc was removed in v2.7.0. As
        // a result, the JS code produced above does *not* provide a name for
        // the module it contains. That's a problem for DartPad, since it's
        // adding the code to a script tag in an iframe rather than loading it
        // as an individual file from baseURL. As a workaround, this replace
        // statement injects a name into the module definition.
        final processedJs = mainJs
            .readAsStringSync()
            .replaceFirst('define([', "define('dartpad_main', [");

        final results = DDCCompilationResults(
          compiledJS: processedJs,
          modulesBaseUrl: 'https://storage.googleapis.com/$_storageBucket'
              '/${_sdk.dartVersion}/',
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      temp.deleteSync(recursive: true);
      _logger.fine('temp folder removed: ${temp.path}');
    }
  }

  Future<void> dispose() async {
    return _ddcDriver.terminateWorkers();
  }
}

/// The result of a dart2js compile.
class CompilationResults {
  final String? compiledJS;
  final String? sourceMap;
  final List<CompilationProblem> problems;

  CompilationResults({
    this.compiledJS,
    this.problems = const <CompilationProblem>[],
    this.sourceMap,
  });

  bool get hasOutput => compiledJS != null && compiledJS!.isNotEmpty;

  /// This is true if there were no errors.
  bool get success => problems.isEmpty;

  @override
  String toString() => success
      ? 'CompilationResults: Success'
      : 'Compilation errors: ${problems.join('\n')}';
}

/// The result of a DDC compile.
class DDCCompilationResults {
  final String? compiledJS;
  final String? modulesBaseUrl;
  final List<CompilationProblem> problems;

  DDCCompilationResults({this.compiledJS, this.modulesBaseUrl})
      : problems = const <CompilationProblem>[];

  DDCCompilationResults.failed(this.problems)
      : compiledJS = null,
        modulesBaseUrl = null;

  bool get hasOutput => compiledJS != null && compiledJS!.isNotEmpty;

  /// This is true if there were no errors.
  bool get success => problems.isEmpty;

  @override
  String toString() => success
      ? 'CompilationResults: Success'
      : 'Compilation errors: ${problems.join('\n')}';
}

/// An issue associated with [CompilationResults].
class CompilationProblem implements Comparable<CompilationProblem> {
  final String message;

  CompilationProblem._(this.message);

  @override
  int compareTo(CompilationProblem other) => message.compareTo(other.message);

  @override
  String toString() => message;
}

/// Copies all of the files in the [from] directory to [to].
///
/// This is similar to `cp -R <from> <to>`:
/// * Symlinks are supported.
/// * Existing files are over-written, if any.
/// * If [to] is within [from], throws [ArgumentError] (an infinite operation).
/// * If [from] and [to] are canonically the same, no operation occurs.
///
/// Returns a future that completes when complete.
void _copyPath(String from, String to) {
  if (_doNothing(from, to)) {
    return;
  }

  Directory(to).createSync(recursive: true);
  for (final file in Directory(from).listSync(recursive: true)) {
    final copyTo = path.join(to, path.relative(file.path, from: from));
    if (file is Directory) {
      Directory(copyTo).createSync(recursive: true);
    } else if (file is File) {
      File(file.path).copySync(copyTo);
    } else if (file is Link) {
      Link(copyTo).createSync(file.targetSync(), recursive: true);
    }
  }
}

bool _doNothing(String from, String to) {
  if (path.canonicalize(from) == path.canonicalize(to)) {
    return true;
  }
  if (path.isWithin(from, to)) {
    throw ArgumentError('Cannot copy from $from to $to');
  }
  return false;
}

/// Remove any references to 'bootstrap.dart' and replace with referenced to
/// 'main.dart'.
String _rewritePaths(String output) {
  final lines = output.split('\n');

  return lines.map((line) {
    final token1 = 'lib/bootstrap.dart:';
    var index = line.indexOf(token1);
    if (index != -1) {
      return 'main.dart:${line.substring(index + token1.length)}';
    }

    final token2 = 'lib/main.dart:';
    index = line.indexOf(token2);
    if (index != -1) {
      return 'main.dart:${line.substring(index + token2.length)}';
    }

    return line;
  }).join('\n');
}
