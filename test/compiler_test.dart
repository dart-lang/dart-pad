// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  Compiler compiler;

  group('compiler', () {
    setUpAll(() async {
      await SdkManager.sdk.init();
      await SdkManager.flutterSdk.init();

      compiler = Compiler(SdkManager.sdk, SdkManager.flutterSdk);
      await compiler.warmup();
    });

    tearDownAll(() async {
      await compiler.dispose();
    });

    test('simple', () async {
      final result = await compiler.compile(sampleCode);
      print(result.problems);

      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.sourceMap, isNull);
    });

    test('compileDDC simple', () async {
      final result = await compiler.compileDDC(sampleCode);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.modulesBaseUrl, isNotEmpty);

      expect(result.compiledJS, contains("define('dartpad_main', ["));
    });

    test('compileDDC with web', () async {
      final result = await compiler.compileDDC(sampleCodeWeb);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.modulesBaseUrl, isNotEmpty);

      expect(result.compiledJS, contains("define('dartpad_main', ["));
    });

    test('compileDDC with Flutter', () async {
      final result = await compiler.compileDDC(sampleCodeFlutter);
      print(result.problems);

      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.modulesBaseUrl, isNotEmpty);

      expect(result.compiledJS, contains("define('dartpad_main', ["));
    });

    test('compileDDC with async', () async {
      final result = await compiler.compileDDC(sampleCodeAsync);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.modulesBaseUrl, isNotEmpty);

      expect(result.compiledJS, contains("define('dartpad_main', ["));
    });

    test('compileDDC with single error', () async {
      final result = await compiler.compileDDC(sampleCodeError);
      expect(result.success, false);
      expect(result.problems.length, 1);
      expect(result.problems[0].toString(),
          contains('Error: Expected \';\' after this.'));
    });

    test('compileDDC with multiple errors', () async {
      final result = await compiler.compileDDC(sampleCodeErrors);
      expect(result.success, false);
      expect(result.problems.length, 1);
      expect(result.problems[0].toString(),
          contains('Error: Method not found: \'print1\'.'));
      expect(result.problems[0].toString(),
          contains('Error: Method not found: \'print2\'.'));
      expect(result.problems[0].toString(),
          contains('Error: Method not found: \'print3\'.'));
    });

    test('sourcemap', () async {
      final result = await compiler.compile(sampleCode, returnSourceMap: true);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.sourceMap, isNotNull);
      expect(result.sourceMap, isNotEmpty);
    });

    test('version', () async {
      final result = await compiler.compile(sampleCode, returnSourceMap: true);
      expect(result.sourceMap, isNotNull);
      expect(result.sourceMap, isNotEmpty);
    });

    test('simple web', () async {
      final result = await compiler.compile(sampleCodeWeb);
      expect(result.success, true);
    });

    test('web async', () async {
      final result = await compiler.compile(sampleCodeAsync);
      expect(result.success, true);
    });

    test('errors', () async {
      final result = await compiler.compile(sampleCodeError);
      expect(result.success, false);
      expect(result.problems.length, 1);
      expect(result.problems[0].toString(), contains('Error: Expected'));
    });

    test('good import', () async {
      const code = '''
import 'dart:html';

void main() {
  var count = querySelector('#count');
  print('hello');
}

''';
      final result = await compiler.compile(code);
      expect(result.problems.length, 0);
    });

    test('bad import - local', () async {
      const code = '''
import 'foo.dart';
void main() { missingMethod ('foo'); }
''';
      final result = await compiler.compile(code);
      expect(result.problems.first.message,
          equals('unsupported import: foo.dart'));
    });

    test('bad import - http', () async {
      const code = '''
import 'http://example.com';
void main() { missingMethod ('foo'); }
''';
      final result = await compiler.compile(code);
      expect(result.problems.first.message,
          equals('unsupported import: http://example.com'));
    });

    test('disallow compiler warnings', () async {
      final result = await compiler.compile(sampleCodeErrors);
      expect(result.success, false);
    });

    test('transitive errors', () async {
      const code = '''
import 'dart:foo';
void main() { print ('foo'); }
''';
      final result = await compiler.compile(code);
      expect(result.problems.length, 1);
    });

    test('errors for dart 2', () async {
      final result = await compiler.compile(sampleDart2Error);
      expect(result.problems.length, 1);
    });
  });
}
