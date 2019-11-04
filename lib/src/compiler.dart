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
  final String sdkPath;
  final FlutterWebManager flutterWebManager;

  final BazelWorkerDriver _ddcDriver;
  String _sdkVersion;

  Compiler(this.sdkPath, this.flutterWebManager)
      : _ddcDriver = BazelWorkerDriver(
            () => Process.start(path.join(sdkPath, 'bin', 'dartdevc'),
                <String>['--persistent_worker']),
            maxWorkers: 1) {
    _sdkVersion = SdkManager.sdk.version;
  }

  bool importsOkForCompile(Set<String> imports) {
    return !flutterWebManager.hasUnsupportedImport(imports);
  }

  /// The version of the SDK this copy of dart2js is based on.
  String get version {
    return File(path.join(sdkPath, 'version')).readAsStringSync().trim();
  }

  Future<CompilationResults> warmup({bool useHtml = false}) {
    return compile(useHtml ? sampleCodeWeb : sampleCode);
  }

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(
    String input, {
    bool returnSourceMap = false,
  }) async {
    Set<String> imports = getAllImportsFor(input);
    if (!importsOkForCompile(imports)) {
      return CompilationResults(problems: <CompilationProblem>[
        CompilationProblem._(
          'unsupported import: ${flutterWebManager.getUnsupportedImport(imports)}',
        ),
      ]);
    }

    Directory temp = await Directory.systemTemp.createTemp('dartpad');

    try {
      List<String> arguments = <String>[
        '--suppress-hints',
        '--terse',
      ];
      if (!returnSourceMap) arguments.add('--no-source-maps');

      arguments.add('--packages=${flutterWebManager.packagesFilePath}');
      arguments.add('-o$kMainDart.js');
      arguments.add(kMainDart);

      String compileTarget = path.join(temp.path, kMainDart);
      File mainDart = File(compileTarget);
      await mainDart.writeAsString(input);

      File mainJs = File(path.join(temp.path, '$kMainDart.js'));
      File mainSourceMap = File(path.join(temp.path, '$kMainDart.js.map'));

      final String dart2JSPath = path.join(sdkPath, 'bin', 'dart2js');
      _logger.info('About to exec: $dart2JSPath $arguments');

      ProcessResult result = await Process.run(dart2JSPath, arguments,
          workingDirectory: temp.path);

      if (result.exitCode != 0) {
        final CompilationResults results =
            CompilationResults(problems: <CompilationProblem>[
          CompilationProblem._(result.stdout as String),
        ]);
        return results;
      } else {
        String sourceMap;
        if (returnSourceMap && await mainSourceMap.exists()) {
          sourceMap = await mainSourceMap.readAsString();
        }
        final CompilationResults results = CompilationResults(
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
          'unsupported import: '
              '${flutterWebManager.getUnsupportedImport(imports)}',
        ),
      ]);
    }
    final temp = await Directory.systemTemp.createTemp('dartpad');
    _logger.info('Temp directory created: ${temp.path}');
    try {
      final compileTarget = path.join(temp.path, kMainDart);
      final mainDart = File(compileTarget);
      await mainDart.writeAsString(input);
      final arguments = [
        '--modules=amd',
        if (flutterWebManager.usesFlutterWeb(imports)) ...[
          '-k',
          '-s',
          flutterWebManager.summaryFilePath,
          '-s',
          '${flutterWebManager.flutterSdk.flutterBinPath}/cache/flutter_web_sdk/flutter_web_sdk/kernel/flutter_ddc_sdk.dill'
        ],
        ...['-o', path.join(temp.path, '$kMainDart.js')],
        '--single-out-file',
        ...['--module-name', 'dartpad_main'],
        compileTarget,
        '--packages=${flutterWebManager.packagesFilePath}',
      ];
      final mainJs = File(path.join(temp.path, '$kMainDart.js'));
      final response = await _ddcDriver
          .doWork(WorkRequest()..arguments.addAll(arguments));
      if (response.exitCode != 0) {
        return DDCCompilationResults.failed(<CompilationProblem>[
          CompilationProblem._(response.output),
        ]);
      } else {
        final results = DDCCompilationResults(
          compiledJS: await mainJs.readAsString(),
          modulesBaseUrl: 'https://storage.googleapis.com/'
              'compilation_artifacts/${SdkManager.flutterSdk.versionFull}/',
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
