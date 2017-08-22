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
    String sdkPath = getSdkPath();

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
      return compiler
          .compile(sampleCode, returnSourceMap: true)
          .then((CompilationResults result) {
        expect(result.success, true);
        expect(result.getOutput(), isNotEmpty);
        expect(result.getSourceMap(), isNotEmpty);
      });
    });

    test('version', () {
      return compiler
          .compile(sampleCode, returnSourceMap: true)
          .then((CompilationResults result) {
        expect(compiler.version, isNotNull);
        expect(compiler.version, startsWith('1.'));
        expect(result.getSourceMap(), isNotEmpty);
      });
    });

    test('checked', () async {
      final String sampleCodeChecked = '''
main() { foo(1); }
void foo(String bar) { print(bar); }
''';

      CompilationResults normal = await compiler.compile(sampleCodeChecked);
      CompilationResults checked =
          await compiler.compile(sampleCodeChecked, useCheckedMode: true);

      expect(true, normal.getOutput() != checked.getOutput());
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
        expect(result.problems[0].toString(), contains("Error: Expected"));
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

    test('allow complier warnings', () async {
      CompilationResults result = await compiler.compile(sampleCodeErrors);
      expect(result.success, true);
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
  });
}
