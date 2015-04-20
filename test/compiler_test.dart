// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:services/src/common.dart';
import 'package:services/src/compiler.dart';
import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:unittest/unittest.dart';

void defineTests() {
  Compiler compiler;

  group('compiler', () {
    String sdkPath = cli_util.getSdkDir([]).path;

    setUp(() {
      compiler = new Compiler(sdkPath);
    });

    test('simple', () {
      return compiler.compile(sampleCode).then((CompilationResults result) {
        expect(result.success, true);
      });
    });

    test('simple web', () {
      return compiler.compile(sampleCodeWeb).then((CompilationResults result) {
        expect(result.success, true);
      });
    });

    test('web async', () {
      return compiler.compile(sampleCodeAsync).then((CompilationResults result) {
        expect(result.success, true);
      });
    });

    test('errors', () {
      return compiler.compile(sampleCodeError).then((CompilationResults result) {
        expect(result.success, false);
        expect(result.problems.length, 1);
        expect(result.problems[0].toString(),
            startsWith("[error] Expected ';' after this"));
      });
    });

    test('errors many', () {
      return compiler.compile(sampleCodeErrors).then((CompilationResults result) {
        expect(result.problems.length, 3);
      });
    });

    test('transitive errors', () {
      final String code = '''
import 'dart:io';
void main() { print ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.length, greaterThan(10));
        List<CompilationProblem> problems = result.problems;
        expect(problems.any((p) => p.isOnSdk), true);
        expect(problems.any((p) => !p.isOnCompileTarget), true);
      });
    });
  });
}
