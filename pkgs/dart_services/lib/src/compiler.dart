// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
library;

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/driver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'project.dart';
import 'pub.dart';
import 'sdk.dart';

Logger _logger = Logger('compiler');

/// An interface to the dart2js compiler. A compiler object can process one
/// compile at a time.
class Compiler {
  final Sdk _sdk;
  final String _dartPath;
  final BazelWorkerDriver _ddcDriver;

  final ProjectTemplates _projectTemplates;

  Compiler(Sdk sdk) : this._(sdk, path.join(sdk.dartSdkPath, 'bin', 'dart'));

  Compiler._(this._sdk, this._dartPath)
      : _ddcDriver = BazelWorkerDriver(
            () => Process.start(_dartPath, [
                  path.join(_sdk.dartSdkPath, 'bin', 'snapshots',
                      'dartdevc.dart.snapshot'),
                  '--persistent_worker'
                ]),
            maxWorkers: 1),
        _projectTemplates = ProjectTemplates.projectTemplates;

  Future<CompilationResults> warmup({bool useHtml = false}) async {
    return compile(useHtml ? sampleCodeWeb : sampleCode);
  }

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(
    String source, {
    bool returnSourceMap = false,
  }) async {
    return compileFiles({kMainDart: source}, returnSourceMap: returnSourceMap);
  }

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compileFiles(
    final Map<String, String> files, {
    bool returnSourceMap = false,
  }) async {
    if (files.isEmpty) {
      return CompilationResults(
          problems: [CompilationProblem._('file list empty')]);
    }
    sanitizeAndCheckFilenames(files);
    final imports = getAllImportsForFiles(files);
    final unsupportedImports = getUnsupportedImports(imports,
        sourcesFileList: files.keys.toList(), devMode: _sdk.devMode);
    if (unsupportedImports.isNotEmpty) {
      return CompilationResults(problems: [
        for (final import in unsupportedImports)
          CompilationProblem._('unsupported import: ${import.uri.stringValue}'),
      ]);
    }

    final temp = await Directory.systemTemp.createTemp('dartpad');
    _logger.fine('Temp directory created: ${temp.path}');

    try {
      await copyPath(_projectTemplates.dartPath, temp.path);
      await Directory(path.join(temp.path, 'lib')).create(recursive: true);

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

      files.forEach((filename, content) async {
        await File(path.join(temp.path, 'lib', filename))
            .writeAsString(content);
      });

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
        if (returnSourceMap && await mainSourceMap.exists()) {
          sourceMap = await mainSourceMap.readAsString();
        }
        final results = CompilationResults(
          compiledJS: await mainJs.readAsString(),
          sourceMap: sourceMap,
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      await temp.delete(recursive: true);
      _logger.fine('temp folder removed: ${temp.path}');
    }
  }

  /// Compile the given string and return the resulting [DDCCompilationResults].
  Future<DDCCompilationResults> compileDDC(String source) async {
    return compileFilesDDC({kMainDart: source});
  }

  /// Compile the given set of source files and return the resulting
  /// [DDCCompilationResults].
  ///
  /// [files] is a map containing the source files in the format
  /// `{ "filename1":"sourcecode1" ... "filenameN":"sourcecodeN"}`.
  Future<DDCCompilationResults> compileFilesDDC(
      Map<String, String> files) async {
    if (files.isEmpty) {
      return DDCCompilationResults.failed(
          [CompilationProblem._('file list empty')]);
    }
    sanitizeAndCheckFilenames(files);
    final imports = getAllImportsForFiles(files);
    final unsupportedImports = getUnsupportedImports(imports,
        sourcesFileList: files.keys.toList(), devMode: _sdk.devMode);
    if (unsupportedImports.isNotEmpty) {
      return DDCCompilationResults.failed([
        for (final import in unsupportedImports)
          CompilationProblem._('unsupported import: ${import.uri.stringValue}'),
      ]);
    }

    final temp = await Directory.systemTemp.createTemp('dartpad');
    _logger.fine('Temp directory created: ${temp.path}');

    try {
      final usingFlutter = usesFlutterWeb(imports, devMode: _sdk.devMode);
      if (usesFirebase(imports)) {
        await copyPath(_projectTemplates.firebasePath, temp.path);
      } else if (usingFlutter) {
        await copyPath(_projectTemplates.flutterPath, temp.path);
      } else {
        await copyPath(_projectTemplates.dartPath, temp.path);
      }

      await Directory(path.join(temp.path, 'lib')).create(recursive: true);

      final bootstrapPath = path.join(temp.path, 'lib', kBootstrapDart);
      final bootstrapContents =
          usingFlutter ? kBootstrapFlutterCode : kBootstrapDartCode;
      await File(bootstrapPath).writeAsString(bootstrapContents);

      files.forEach((filename, content) async {
        await File(path.join(temp.path, 'lib', filename))
            .writeAsString(content);
      });

      final arguments = <String>[
        '--modules=amd',
        '--no-summarize',
        if (usingFlutter) ...[
          '-s',
          _projectTemplates.summaryFilePath,
          '-s',
          '${_sdk.flutterWebSdkPath}/flutter_ddc_sdk_sound.dill',
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
          await _ddcDriver.doWork(WorkRequest()..arguments.addAll(arguments));

      if (response.exitCode != 0) {
        return DDCCompilationResults.failed(
            [CompilationProblem._(response.output)]);
      } else {
        // The `--single-out-file` option for dartdevc was removed in v2.7.0. As
        // a result, the JS code produced above does *not* provide a name for
        // the module it contains. That's a problem for DartPad, since it's
        // adding the code to a script tag in an iframe rather than loading it
        // as an individual file from baseURL. As a workaround, this replace
        // statement injects a name into the module definition.
        final processedJs = (await mainJs.readAsString())
            .replaceFirst('define([', "define('dartpad_main', [");

        final results = DDCCompilationResults(
          compiledJS: processedJs,
          modulesBaseUrl: 'https://storage.googleapis.com/nnbd_artifacts'
              '/${_sdk.versionFull}/',
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      await temp.delete(recursive: true);
      _logger.fine('temp folder removed: ${temp.path}');
    }
  }

  /// Compile the given source file and return the resulting
  /// [FlutterBuildResults].
  Future<FlutterBuildResults> flutterBuild(String source) async {
    final unsupportedImports = getUnsupportedImports(getAllImportsFor(source));
    if (unsupportedImports.isNotEmpty) {
      final message =
          unsupportedImports.map((import) => import.uri.stringValue).join('\n');
      return FlutterBuildResults.failed(message);
    }

    // TODO: Recycle this project directory.
    final tempDir = await Directory.systemTemp.createTemp('dartpad');

    try {
      await copyPath(_projectTemplates.flutterPath, tempDir.path);

      // Update lib/main.dart.
      final sourceFile = File(path.join(tempDir.path, 'lib', kMainDart));
      sourceFile.parent.createSync();
      sourceFile.writeAsStringSync(source);

      final arguments = <String>[
        'build',
        'web',

        // This disables minification.
        '--dart2js-optimization=O1',

        // With the web renderer, we don't need to load other (skiawasm) resources.
        // TODO(devoncarew): Look into use the skiawasm backend.
        '--web-renderer=html',

        // This disables the service worker / caching path.
        '--pwa-strategy=none',

        '--no-tree-shake-icons',

        if (_sdk.experiments.isNotEmpty)
          '--enable-experiment=${_sdk.experiments.join(",")}',
      ];

      // TODO: Serialize this request - only one can run at a time.
      final result = await Process.run(
        _sdk.flutterToolPath,
        arguments,
        workingDirectory: tempDir.path,
      );

      if (result.exitCode != 0) {
        return FlutterBuildResults.failed(
            '${result.stdout}\n${result.stderr}'.trim());
      }

      // Return the compiled build/web/main.dart.js file.
      final jsOutFile =
          File(path.join(tempDir.path, 'build', 'web', 'main.dart.js'));
      return FlutterBuildResults.success(
          compiledJavaScript: jsOutFile.readAsStringSync());
    } finally {
      await tempDir.delete(recursive: true);
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

class FlutterBuildResults {
  final String? compiledJavaScript;
  final String? compilationIssues;

  FlutterBuildResults.success({required this.compiledJavaScript})
      : compilationIssues = null;

  FlutterBuildResults.failed(this.compilationIssues)
      : compiledJavaScript = null;

  bool get hasOutput => compiledJavaScript != null;

  bool get success => compilationIssues == null;
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
Future<void> copyPath(String from, String to) async {
  if (_doNothing(from, to)) {
    return;
  }
  await Directory(to).create(recursive: true);
  await for (final file in Directory(from).list(recursive: true)) {
    final copyTo = path.join(to, path.relative(file.path, from: from));
    if (file is Directory) {
      await Directory(copyTo).create(recursive: true);
    } else if (file is File) {
      await File(file.path).copy(copyTo);
    } else if (file is Link) {
      await Link(copyTo).create(await file.target(), recursive: true);
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
