// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
library services.compiler;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'pub.dart';

Logger _logger = Logger('compiler');

const String BAD_IMPORT_ERROR_MSG =
    'Imports other than dart: are not supported on Dartpad';

/// An interface to the dart2js compiler. A compiler object can process one
/// compile at a time.
class Compiler {
  final String sdkPath;
  final Pub pub;

  Compiler(this.sdkPath, [this.pub]);

  bool importsOkForCompile(String dartSource) {
    Set<String> imports = getAllUnsafeImportsFor(dartSource);
    return imports.every((String import) => import.startsWith('dart:'));
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
    if (!importsOkForCompile(input)) {
      return CompilationResults(problems: <CompilationProblem>[
        CompilationProblem._(BAD_IMPORT_ERROR_MSG),
      ]);
    }

    Directory temp = Directory.systemTemp.createTempSync('dartpad');

    try {
      List<String> arguments = <String>[
        '--suppress-hints',
        '--terse',
      ];
      if (!returnSourceMap) arguments.add('--no-source-maps');

      arguments.add('-o$kMainDart.js');
      arguments.add(kMainDart);

      String compileTarget = path.join(temp.path, kMainDart);
      File mainDart = File(compileTarget);
      mainDart.writeAsStringSync(input);

      File mainJs = File(path.join(temp.path, '$kMainDart.js'));
      File mainSourceMap = File(path.join(temp.path, '$kMainDart.js.map'));

      final String dart2JSPath = path.join(sdkPath, 'bin', 'dart2js');
      _logger.info('About to exec: $dart2JSPath $arguments');

      ProcessResult result =
          Process.runSync(dart2JSPath, arguments, workingDirectory: temp.path);

      if (result.exitCode != 0) {
        final CompilationResults results =
            CompilationResults(problems: <CompilationProblem>[
          CompilationProblem._(result.stdout),
        ]);
        return results;
      } else {
        String sourceMap;
        if (returnSourceMap && mainSourceMap.existsSync()) {
          sourceMap = mainSourceMap.readAsStringSync();
        }
        final CompilationResults results = CompilationResults(
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
      _logger.info('temp folder removed: ${temp.path}');
    }
  }

  /// Compile the given string and return the resulting [DDCCompilationResults].
  Future<DDCCompilationResults> compileDDC(String input) async {
    if (!importsOkForCompile(input)) {
      return DDCCompilationResults.failed(<CompilationProblem>[
        CompilationProblem._(BAD_IMPORT_ERROR_MSG),
      ]);
    }

    Directory temp = Directory.systemTemp.createTempSync('dartpad');

    try {
      List<String> arguments = <String>[
        '--modules=amd',
      ];
      arguments.addAll(<String>['-o', '$kMainDart.js']);
      arguments.add('--single-out-file');
      arguments.addAll(<String>['--module-name', 'dartpad_main']);
      arguments.add(kMainDart);

      String compileTarget = path.join(temp.path, kMainDart);
      File mainDart = File(compileTarget);
      mainDart.writeAsStringSync(input);

      File mainJs = File(path.join(temp.path, '$kMainDart.js'));

      final String dartdevcPath = path.join(sdkPath, 'bin', 'dartdevc');
      _logger.info('About to exec: $dartdevcPath $arguments');

      final ProcessResult result =
          Process.runSync(dartdevcPath, arguments, workingDirectory: temp.path);

      if (result.exitCode != 0) {
        return DDCCompilationResults.failed(<CompilationProblem>[
          CompilationProblem._(result.stdout),
        ]);
      } else {
        // TODO(devoncarew): The hard-coded URL below will be replaced with
        // something based on the sdk version.
        final DDCCompilationResults results = DDCCompilationResults(
          compiledJS: mainJs.readAsStringSync(),
          modulesBaseUrl:
              'https://storage.cloud.google.com/compilation_artifacts/',
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning('Compiler failed: $e\n$st');
      rethrow;
    } finally {
      temp.deleteSync(recursive: true);
      _logger.info('temp folder removed: ${temp.path}');
    }
  }
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

  bool get hasOutput => compiledJS.isNotEmpty;

  /// This is true if there were no errors.
  bool get success => problems.isEmpty;
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
