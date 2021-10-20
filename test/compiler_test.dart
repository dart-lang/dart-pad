// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.compiler_test;

import 'dart:io';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  late Compiler compiler;

  for (final nullSafety in [false, true]) {
    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} Compiler', () {
      setUpAll(() async {
        final channel =
            Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;
        compiler = Compiler(Sdk.create(channel), nullSafety);
        await compiler.warmup();
      });

      tearDownAll(() async {
        await compiler.dispose();
      });

      test('simple', () async {
        final result = await compiler.compile(sampleCode);

        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.sourceMap, isNull);
      });

      Future<void> Function() _generateCompilerDDCTest(String sample) =>
          () async {
            final result = await compiler.compileDDC(sample);

            expect(result.success, true);
            expect(result.compiledJS, isNotEmpty);
            expect(result.modulesBaseUrl, isNotEmpty);

            expect(result.compiledJS, contains("define('dartpad_main', ["));
          };

      test(
        'compileDDC simple',
        _generateCompilerDDCTest(sampleCode),
      );

      test(
        'compileDDC with web',
        _generateCompilerDDCTest(
            nullSafety ? sampleCodeWebNullSafe : sampleCodeWeb),
      );

      test(
        'compileDDC with Flutter',
        _generateCompilerDDCTest(sampleCodeFlutter),
      );

      test(
        'compileDDC with Flutter Counter',
        _generateCompilerDDCTest(nullSafety
            ? sampleCodeFlutterCounterNullSafe
            : sampleCodeFlutterCounter),
      );

      test(
        'compileDDC with Flutter Sunflower',
        _generateCompilerDDCTest(nullSafety
            ? sampleCodeFlutterSunflowerNullSafe
            : sampleCodeFlutterSunflower),
      );

      test(
        'compileDDC with Flutter Draggable Card',
        _generateCompilerDDCTest(nullSafety
            ? sampleCodeFlutterDraggableCardNullSafe
            : sampleCodeFlutterDraggableCard),
      );

      test(
        'compileDDC with Flutter Implicit Animations',
        _generateCompilerDDCTest(nullSafety
            ? sampleCodeFlutterImplicitAnimationsNullSafe
            : sampleCodeFlutterImplicitAnimations),
      );

      test(
        'compileDDC with async',
        _generateCompilerDDCTest(
            nullSafety ? sampleCodeAsyncNullSafe : sampleCodeAsync),
      );

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
        final result =
            await compiler.compile(sampleCode, returnSourceMap: true);
        expect(result.success, true);
        expect(result.compiledJS, isNotEmpty);
        expect(result.sourceMap, isNotNull);
        expect(result.sourceMap, isNotEmpty);
      });

      test('version', () async {
        final result =
            await compiler.compile(sampleCode, returnSourceMap: true);
        expect(result.sourceMap, isNotNull);
        expect(result.sourceMap, isNotEmpty);
      });

      test('simple web', () async {
        final result = await compiler
            .compile(nullSafety ? sampleCodeWebNullSafe : sampleCodeWeb);
        expect(result.success, true);
      });

      test('web async', () async {
        final result = await compiler
            .compile(nullSafety ? sampleCodeAsyncNullSafe : sampleCodeAsync);
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
        expect(result.problems, hasLength(1));
        expect(result.problems.single.message,
            equals('unsupported import: foo.dart'));
      });

      test('bad import - http', () async {
        const code = '''
import 'http://example.com';
void main() { missingMethod ('foo'); }
''';
        final result = await compiler.compile(code);
        expect(result.problems, hasLength(1));
        expect(result.problems.single.message,
            equals('unsupported import: http://example.com'));
      });

      test('multiple bad imports', () async {
        const code = '''
import 'package:foo';
import 'package:bar';
''';
        final result = await compiler.compile(code);
        expect(result.problems, hasLength(2));
        expect(result.problems[0].message,
            equals('unsupported import: package:foo'));
        expect(result.problems[1].message,
            equals('unsupported import: package:bar'));
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
}
