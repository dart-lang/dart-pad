// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  Compiler compiler;
  FlutterWebManager flutterWebManager;

  group('compiler', () {
    setUpAll(() async {
      await SdkManager.sdk.init();
      await SdkManager.flutterSdk.init();

      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      await flutterWebManager.initFlutterWeb();

      compiler =
          Compiler(SdkManager.sdk, SdkManager.flutterSdk, flutterWebManager);
    });

    tearDownAll(() async {
      await compiler.dispose();
    });

    test('simple', () {
      return compiler.compile(sampleCode).then((CompilationResults result) {
        print(result.problems);

        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.sourceMap, isNull);
      });
    });

    test('compileDDC simple', () {
      return compiler
          .compileDDC(sampleCode)
          .then((DDCCompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.modulesBaseUrl, isNotEmpty);

        expect(result.compiledJS, contains("define('dartpad_main', ["));
      });
    });

    test('compileDDC with web', () {
      return compiler
          .compileDDC(sampleCodeWeb)
          .then((DDCCompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.modulesBaseUrl, isNotEmpty);

        expect(result.compiledJS, contains("define('dartpad_main', ["));
      });
    });

    test('compileDDC with Flutter', () {
      return compiler
          .compileDDC(sampleCodeFlutter)
          .then((DDCCompilationResults result) {
        print(result.problems);

        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.modulesBaseUrl, isNotEmpty);

        expect(result.compiledJS, contains("define('dartpad_main', ["));
      });
    });

    test('compileDDC with async', () {
      return compiler
          .compileDDC(sampleCodeAsync)
          .then((DDCCompilationResults result) {
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.modulesBaseUrl, isNotEmpty);

        expect(result.compiledJS, contains("define('dartpad_main', ["));
      });
    });

    test('compileDDC with single error', () {
      return compiler
          .compileDDC(sampleCodeError)
          .then((DDCCompilationResults result) {
        expect(result.success, false);
        expect(result.problems.length, 1);
        expect(result.problems[0].toString(),
            contains('Error: Expected \';\' after this.'));
      });
    });

    test('compileDDC with multiple errors', () {
      return compiler
          .compileDDC(sampleCodeErrors)
          .then((DDCCompilationResults result) {
        expect(result.success, false);
        expect(result.problems.length, 1);
        expect(result.problems[0].toString(),
            contains('Error: Method not found: \'print1\'.'));
        expect(result.problems[0].toString(),
            contains('Error: Method not found: \'print2\'.'));
        expect(result.problems[0].toString(),
            contains('Error: Method not found: \'print3\'.'));
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
      const code = '''
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
      const code = '''
import 'foo.dart';
void main() { missingMethod ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.first.message,
            equals('unsupported import: foo.dart'));
      });
    });

    test('bad import - http', () {
      const code = '''
import 'http://example.com';
void main() { missingMethod ('foo'); }
''';
      return compiler.compile(code).then((CompilationResults result) {
        expect(result.problems.first.message,
            equals('unsupported import: http://example.com'));
      });
    });

    test('disallow compiler warnings', () async {
      final result = await compiler.compile(sampleCodeErrors);
      expect(result.success, false);
    });

    test('transitive errors', () {
      const code = '''
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
