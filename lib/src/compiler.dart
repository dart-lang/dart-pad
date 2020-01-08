// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
library services.compiler;

import 'dart:async';
import 'dart:io';

import 'package:bazel_worker/driver.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'flutter_web.dart';
import 'pub.dart';
import 'sdk_manager.dart';

Logger _logger = Logger('compiler');

/// An interface to the dart2js compiler. A compiler object can process one
/// compile at a time.
class Compiler {
  final Sdk _sdk;
  final FlutterSdk _flutterSdk;
  final FlutterWebManager _flutterWebManager;
  final String _dartdevcPath;
  final BazelWorkerDriver _ddcDriver;

  Compiler(this._sdk, this._flutterSdk, this._flutterWebManager)
      : _dartdevcPath = path.join(_flutterSdk.sdkPath, 'bin', 'dartdevc'),
        _ddcDriver = BazelWorkerDriver(
            () => Process.start(
                  path.join(_flutterSdk.sdkPath, 'bin', 'dartdevc'),
                  <String>['--persistent_worker'],
                ),
            maxWorkers: 1);

  bool importsOkForCompile(Set<String> imports) {
    return !_flutterWebManager.hasUnsupportedImport(imports);
  }

  Future<CompilationResults> warmup({bool useHtml = false}) {
    return compile(useHtml ? sampleCodeWeb : sampleCode);
  }

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(
    String input, {
    bool returnSourceMap = false,
  }) async {
    final imports = getAllImportsFor(input);
    if (!importsOkForCompile(imports)) {
      return CompilationResults(problems: <CompilationProblem>[
        CompilationProblem._(
          'unsupported import: ${_flutterWebManager.getUnsupportedImport(imports)}',
        ),
      ]);
    }

    final temp = await Directory.systemTemp.createTemp('dartpad');
    _logger.info('Temp directory created: ${temp.path}');

    try {
      final arguments = <String>[
        '--suppress-hints',
        '--terse',
        if (!returnSourceMap) '--no-source-maps',
        '--packages=${_flutterWebManager.packagesFilePath}',
        ...['-o', '$kMainDart.js'],
        kMainDart,
      ];

      final compileTarget = path.join(temp.path, kMainDart);
      final mainDart = File(compileTarget);
      await mainDart.writeAsString(input);

      final mainJs = File(path.join(temp.path, '$kMainDart.js'));
      final mainSourceMap = File(path.join(temp.path, '$kMainDart.js.map'));

      final dart2JSPath = path.join(_sdk.sdkPath, 'bin', 'dart2js');
      _logger.info('About to exec: $dart2JSPath $arguments');

      final result = await Process.run(dart2JSPath, arguments,
          workingDirectory: temp.path);

      if (result.exitCode != 0) {
        final results = CompilationResults(problems: <CompilationProblem>[
          CompilationProblem._(result.stdout as String),
        ]);
        return results;
      } else {
        String sourceMap;
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
      _logger.info('temp folder removed: ${temp.path}');
    }
  }

  /// Compile the given string and return the resulting [DDCCompilationResults].
  Future<DDCCompilationResults> compileDDC(String input) async {
    final imports = getAllImportsFor(input);
    if (!importsOkForCompile(imports)) {
      return DDCCompilationResults.failed(<CompilationProblem>[
        CompilationProblem._(
          'unsupported import: ${_flutterWebManager.getUnsupportedImport(imports)}',
        ),
      ]);
    }

    final temp = await Directory.systemTemp.createTemp('dartpad');
    _logger.info('Temp directory created: ${temp.path}');

    try {
      final usingFlutter = _flutterWebManager.usesFlutterWeb(imports);

      final mainPath = path.join(temp.path, kMainDart);
      final bootstrapPath = path.join(temp.path, kBootstrapDart);
      final bootstrapContents =
          usingFlutter ? kBootstrapFlutterCode : kBootstrapDartCode;

      await File(bootstrapPath).writeAsString(bootstrapContents);
      await File(mainPath).writeAsString(input);

      final arguments = <String>[
        '--modules=amd',
        if (usingFlutter) ...[
          '-s',
          _flutterWebManager.summaryFilePath,
          '-s',
          '${_flutterSdk.flutterBinPath}/cache/flutter_web_sdk/flutter_web_sdk/kernel/flutter_ddc_sdk.dill'
        ],
        ...['-o', path.join(temp.path, '$kMainDart.js')],
        ...['--module-name', 'dartpad_main'],
        bootstrapPath,
        '--packages=${_flutterWebManager.packagesFilePath}',
      ];

      final mainJs = File(path.join(temp.path, '$kMainDart.js'));

      _logger.info('About to exec "$_dartdevcPath ${arguments.join(' ')}"');
      _logger.info('Compiling: $input');

      final response =
          await _ddcDriver.doWork(WorkRequest()..arguments.addAll(arguments));

      if (response.exitCode != 0) {
        return DDCCompilationResults.failed(<CompilationProblem>[
          CompilationProblem._(response.output),
        ]);
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
          modulesBaseUrl: 'https://storage.googleapis.com/'
              'compilation_artifacts/${_flutterSdk.versionFull}/',
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      await temp.delete(recursive: true);
      _logger.info('temp folder removed: ${temp.path}');
    }
  }

  Future<void> dispose() => _ddcDriver.terminateWorkers();
}

/// The result of a dart2js compile.
class CompilationResults {
  final String compiledJS;
  final String sourceMap;
  final List<CompilationProblem> problems;

  CompilationResults({
    this.compiledJS,
    this.problems = const <CompilationProblem>[],
    this.sourceMap,
  });

  bool get hasOutput => compiledJS != null && compiledJS.isNotEmpty;

  /// This is true if there were no errors.
  bool get success => problems.isEmpty;

  @override
  String toString() => success
      ? 'CompilationResults: Success'
      : 'Compilation errors: ${problems.join('\n')}';
}

/// The result of a DDC compile.
class DDCCompilationResults {
  final String compiledJS;
  final String modulesBaseUrl;
  final List<CompilationProblem> problems;

  DDCCompilationResults({this.compiledJS, this.modulesBaseUrl})
      : problems = const <CompilationProblem>[];

  DDCCompilationResults.failed(this.problems)
      : compiledJS = null,
        modulesBaseUrl = null;

  bool get hasOutput => compiledJS != null && compiledJS.isNotEmpty;

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
