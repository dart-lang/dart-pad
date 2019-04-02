// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  Compiler compiler;

  group('compiler', () {
    setUp(() {
      compiler = Compiler(sdkPath);
    });

    test('simple', () {
      return compiler.compile(sampleCode).then((CompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.sourceMap, isNull);
      });
    });

    test('simple ddc', () {
      return compiler
          .compileDDC(sampleCode)
          .then((DDCCompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.modulesBaseUrl, isNotEmpty);

        expect(result.compiledJS, contains("define('dartpad_main', ["));
      });
    });

    test('sourcemap', () {
      return compiler
          .compile(sampleCode, returnSourceMap: true)
          .then((CompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.sourceMap, isNotNull);
        expect(result.sourceMap, isNotEmpty);
      });
    });

    test('version', () {
      return compiler
          .compile(sampleCode, returnSourceMap: true)
          .then((CompilationResults result) {
        expect(compiler.version, isNotNull);
        expect(compiler.version, startsWith('2.'));
        expect(result.sourceMap, isNotNull);
        expect(result.sourceMap, isNotEmpty);
      });
    });

    test('simple web', () {
      return compiler.compile(sampleCodeWeb).then((CompilationResults result) {
        expect(result.success, true);
      });
    });

    test('web async', () {
      return compiler
          .compile(sampleCodeAsync)
          .then((CompilationResults result) {
        expect(result.success, true);
      });
    });

    test('errors', () {
      return compiler
          .compile(sampleCodeError)
          .then((CompilationResults result) {
        expect(result.success, false);
        expect(result.problems.length, 1);
        expect(result.problems[0].toString(), contains('Error: Expected'));
      });
    });

    test('good import', () {
      final String code = '''
import 'dart:html';

void main() {
  var count = querySelector('#count');
  print('hello');
}

''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.length, 0);
      });
    });

    test('bad import - local', () {
      final String code = '''
import 'foo.dart';
void main() { missingMethod ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.first.message == BAD_IMPORT_ERROR_MSG, true);
      });
    });

    test('bad import - http', () {
      final String code = '''
import 'http://example.com';
void main() { missingMethod ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.first.message == BAD_IMPORT_ERROR_MSG, true);
      });
    });

    test('disallow compiler warnings', () async {
      CompilationResults result = await compiler.compile(sampleCodeErrors);
      expect(result.success, false);
    });

    test('transitive errors', () {
      final String code = '''
import 'dart:foo';
void main() { print ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.length, 1);
      });
    });

    test('errors for dart 2', () {
      return compiler
          .compile(sampleDart2Error)
          .then((CompilationResults result) {
        expect(result.problems.length, 1);
      });
    });
  });
}
