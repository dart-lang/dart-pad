// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:services/src/common.dart';
import 'package:services/src/compiler.dart';
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
        expect(result.getOutput(), isNotEmpty);
        expect(result.getSourceMap(), isEmpty);
      });
    });

    test('sourcemap', () {
      return compiler.compile(sampleCode, returnSourceMap: true).then(
          (CompilationResults result) {
        expect(result.success, true);
        expect(result.getOutput(), isNotEmpty);
        expect(result.getSourceMap(), isNotEmpty);
      });
    });

    test('version', () {
      return compiler.compile(sampleCode, returnSourceMap: true).then(
          (CompilationResults result) {
        expect(compiler.version, isNotNull);
        expect(compiler.version, startsWith('1.'));
        expect(result.getSourceMap(), isNotEmpty);
      });
    });

    // TODO: How to get different source when compiling with --checked?
//    test('checked', () {
//      final String sampleCodeChecked = '''
//main() { foo(1); }
//void foo(String bar) { print(bar); }
//''';
//
//      String normal;
//      String checked;
//
//      return compiler.compile(sampleCodeChecked).then((result) {
//        normal = result.getOutput();
//        return compiler.compile(sampleCodeChecked, useCheckedMode: true).then((result) {
//          checked = result.getOutput();
//
//          expect(true, checked != normal);
//        });
//      });
//    });

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
        expect(result.problems.length, 1);
      });
    });
  });
}
