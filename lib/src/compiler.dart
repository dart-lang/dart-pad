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

const BAD_IMPORT_ERROR_MSG =
    "Imports other than dart: are not supported on Dartpad";

/// An interface to the dart2js compiler. A compiler object can process one
/// compile at a time.
class Compiler {
  final String sdkPath;
  final Pub pub;

  Compiler(this.sdkPath, [this.pub]);

  bool importsOkForCompile(String dartSource) {
    Set<String> imports = getAllUnsafeImportsFor(dartSource);
    return imports.every((import) => import.startsWith("dart:"));
  }

  /// The version of the SDK this copy of dart2js is based on.
  String get version =>
      File(path.join(sdkPath, 'version')).readAsStringSync().trim();

  Future warmup({bool useHtml = false}) =>
      compile(useHtml ? sampleCodeWeb : sampleCode);

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(String input,
      {bool returnSourceMap = false}) async {
    if (!importsOkForCompile(input)) {
      CompilationResults failedResults = CompilationResults('', problems: [
        CompilationProblem._(BAD_IMPORT_ERROR_MSG),
      ]);
      return Future.value(failedResults);
    }

    Directory temp = Directory.systemTemp.createTempSync('dartpad');

    try {
      List<String> arguments = [
        '--suppress-hints',
        '--terse',
      ];
      if (!returnSourceMap) arguments.add('--no-source-maps');

      arguments.add('-o${kMainDart}.js');
      arguments.add(kMainDart);

      String compileTarget = path.join(temp.path, kMainDart);
      File mainDart = File(compileTarget);
      mainDart.writeAsStringSync(input);

      File mainJs = File(path.join(temp.path, '${kMainDart}.js'));
      File mainSourceMap = File(path.join(temp.path, '${kMainDart}.js.map'));

      final dart2JSPath = path.join(sdkPath, 'bin', 'dart2js');
      _logger.info('About to exec: $dart2JSPath $arguments');

      ProcessResult result =
          Process.runSync(dart2JSPath, arguments, workingDirectory: temp.path);

      if (result.exitCode != 0) {
        final CompilationResults results = CompilationResults('', problems: [
          CompilationProblem._(result.stdout),
        ]);
        return results;
      } else {
        String sourceMap;
        if (returnSourceMap && mainSourceMap.existsSync()) {
          sourceMap = mainSourceMap.readAsStringSync();
        }
        final CompilationResults results = CompilationResults(
          mainJs.readAsStringSync(),
          sourceMap: sourceMap,
        );
        return results;
      }
    } catch (e, st) {
      _logger.warning("Compiler failed: $e /n $st");
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

  CompilationResults(
    this.compiledJS, {
    this.problems = const [],
    this.sourceMap,
  });

  bool get hasOutput => compiledJS.isNotEmpty;

  /// This is true if there were no errors.
  bool get success => problems.isEmpty;
}

// todo: support multi

/// The result of a DDC compile.
class DraftCompilationResults {
  final String compiledJS;
  final List<CompilationProblem> problems;

  DraftCompilationResults(
    this.compiledJS, {
    this.problems = const [],
  });

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
