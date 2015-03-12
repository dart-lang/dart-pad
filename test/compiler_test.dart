// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:services/src/common.dart';
import 'package:services/src/compiler.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:unittest/unittest.dart';

void defineTests() {
  Compiler compiler;

  group('compiler', () {
    String sdkPath = grinder.getSdkDir().path;

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
  });
}
