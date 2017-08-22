// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This library is a wrapper around the Dart to JavaScript (dart2js) compiler.
 */
library services.compiler;

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

import 'common.dart';
import 'pub.dart';

Logger _logger = new Logger('compiler');

const BAD_IMPORT_ERROR_MSG =
    "Imports other than dart: are not supported on Dartpad";

/**
 * An interface to the dart2js compiler. A compiler object can process one
 * compile at a time.
 */
class Compiler {
  final String sdkPath;
  final Pub pub;

  Compiler(this.sdkPath, [this.pub]);

  bool importsOkForCompile(String dartSource) {
    Set<String> imports = getAllUnsafeImportsFor(dartSource);
    return imports.every((import) => import.startsWith("dart:"));
  }

  /// The version of the SDK this copy of dart2js is based on.
  String get version {
    String ver = versionFull;
    if (ver.contains('-')) ver = ver.substring(0, ver.indexOf('-'));
    return ver;
  }

  String get versionFull =>
      new File(path.join(sdkPath, 'version')).readAsStringSync().trim();

  Future warmup({bool useHtml: false}) =>
      compile(useHtml ? sampleCodeWeb : sampleCode);

  /// Compile the given string and return the resulting [CompilationResults].
  Future<CompilationResults> compile(String input,
      {bool useCheckedMode: false, bool returnSourceMap: false}) async {
    if (!importsOkForCompile(input)) {
      var failedResults = new CompilationResults();
      failedResults.problems
          .add(new CompilationProblem._(BAD_IMPORT_ERROR_MSG));
      return new Future.value(failedResults);
    }

    // ignore: unused_local_variable
    PubHelper pubHelper;
    if (pub != null) {
      pubHelper = await pub.createPubHelperForSource(input);
    }

    Directory temp = Directory.systemTemp.createTempSync('dartpad');

    try {
      List<String> arguments = [
        '--suppress-hints',
        '--terse',
      ];

      if (useCheckedMode) arguments.add('--checked');
      if (!returnSourceMap) arguments.add('--no-source-maps');

      arguments.add('-o${kMainDart}.js');
      arguments.add(kMainDart);

      File mainDart = new File(path.join(temp.path, kMainDart));
      mainDart.writeAsStringSync(input);

      File mainJs = new File(path.join(temp.path, '${kMainDart}.js'));
      File mainSourceMap =
          new File(path.join(temp.path, '${kMainDart}.js.map'));

      ProcessResult result = Process.runSync(
          path.join(sdkPath, 'bin', 'dart2js'), arguments,
          workingDirectory: temp.path);
      if (result.exitCode != 0) {
        CompilationResults results = new CompilationResults();
        results._problems.add(new CompilationProblem._(result.stdout));
        return results;
      } else {
        CompilationResults results = new CompilationResults();
        results._compiledJS.write(mainJs.readAsStringSync());
        if (returnSourceMap && mainSourceMap.existsSync()) {
          results._sourceMap.write(mainSourceMap.readAsStringSync());
        }
        return results;
      }
    } finally {
      temp.deleteSync(recursive: true);
      _logger.info('temp file removed: ${temp.path}');
    }
  }
}

/// The result of a dart2js compile.
class CompilationResults {
  final StringBuffer _compiledJS = new StringBuffer();
  final StringBuffer _sourceMap = new StringBuffer();
  final List<CompilationProblem> _problems = [];

  CompilationResults();

  bool get hasOutput => _compiledJS.isNotEmpty;

  String getOutput() => _compiledJS.toString();

  String getSourceMap() => _sourceMap.toString();

  List<CompilationProblem> get problems => _problems;

  /// This is true if there were no errors.
  bool get success => _problems.isEmpty;
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
