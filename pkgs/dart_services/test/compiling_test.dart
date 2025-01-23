// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/compiling.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:test/test.dart';

import 'src/sample_code.dart';

void main() => defineTests();

void defineTests() {
  group('compiling', () {
    late Compiler compiler;

    setUpAll(() async {
      compiler =
          Compiler(Sdk.fromLocalFlutter(), storageBucket: 'nnbd_artifacts');
    });

    tearDownAll(() async {
      await compiler.dispose();
    });

    test('simple', () async {
      final result = await compiler.compile(sampleCode);

      expect(result.problems, isEmpty);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.sourceMap, isNull);
    });

    void testDDCEndpoint(String endpointName,
        {Future<DDCCompilationResults> Function(String source)? endpoint,
        Future<DDCCompilationResults> Function(String source, String deltaDill)?
            reloadEndpoint,
        required bool expectDeltaDill,
        required String compiledIndicator}) {
      group(endpointName, () {
        Future<void> Function() generateEndpointTest(String sample) {
          return () async {
            DDCCompilationResults result;
            if (endpoint != null) {
              result = await endpoint(sample);
            } else {
              result = await reloadEndpoint!(sample, sampleDillFile);
            }
            expect(result.problems, isEmpty);
            expect(result.success, true);
            expect(result.compiledJS, isNotEmpty);
            expect(result.deltaDill, expectDeltaDill ? isNotEmpty : isNull);
            expect(result.modulesBaseUrl, isNotEmpty);

            expect(result.compiledJS, contains(compiledIndicator));
          };
        }

        test(
          'simple',
          generateEndpointTest(sampleCode),
        );

        test(
          'with web',
          generateEndpointTest(sampleCodeWeb),
        );

        test(
          'with Flutter',
          generateEndpointTest(sampleCodeFlutter),
        );

        test(
          'with Flutter Counter',
          generateEndpointTest(sampleCodeFlutterCounter),
        );

        test(
          'with Flutter Sunflower',
          generateEndpointTest(sampleCodeFlutterSunflower),
        );

        test(
          'with Flutter Draggable Card',
          generateEndpointTest(sampleCodeFlutterDraggableCard),
        );

        test(
          'with Flutter Implicit Animations',
          generateEndpointTest(sampleCodeFlutterImplicitAnimations),
        );

        test(
          'with async',
          generateEndpointTest(sampleCodeAsync),
        );

        test('with single error', () async {
          DDCCompilationResults result;
          if (endpoint != null) {
            result = await endpoint(sampleCodeError);
          } else {
            result = await reloadEndpoint!(sampleCodeError, '');
          }
          expect(result.success, false);
          expect(result.problems.length, 1);
          expect(result.problems[0].toString(),
              contains('Error: Expected \';\' after this.'));
        });

        test('with no main', () async {
          DDCCompilationResults result;
          if (endpoint != null) {
            result = await endpoint(sampleCodeNoMain);
          } else {
            result = await reloadEndpoint!(sampleCodeNoMain, sampleDillFile);
          }
          expect(result.success, false);
          expect(result.problems.length, 1);
          expect(
            result.problems.first.message,
            contains(
                "Invoked Dart programs must have a 'main' function defined"),
          );
        });

        test('with multiple errors', () async {
          DDCCompilationResults result;
          if (endpoint != null) {
            result = await endpoint(sampleCodeErrors);
          } else {
            result = await reloadEndpoint!(sampleCodeErrors, sampleDillFile);
          }
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
    }

    testDDCEndpoint('compileDDC',
        endpoint: (source) => compiler.compileDDC(source),
        expectDeltaDill: false,
        compiledIndicator: "define('dartpad_main', [");
    testDDCEndpoint('compileNewDDC',
        endpoint: (source) => compiler.compileNewDDC(source),
        expectDeltaDill: true,
        compiledIndicator: 'defineLibrary("package:dartpad_sample/main.dart"');
    testDDCEndpoint('compileNewDDC',
        reloadEndpoint: (source, deltaDill) =>
            compiler.compileNewDDCReload(source, deltaDill),
        expectDeltaDill: true,
        compiledIndicator: 'defineLibrary("package:dartpad_sample/main.dart"');

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

    test('good import - empty', () async {
      const code = '''
import '' as foo;

int bar = 2;

void main() {
  print(foo.bar);
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
          contains("Error when reading 'lib/foo.dart'"));
    });

    test('bad import - http', () async {
      const code = '''
import 'http://example.com';
void main() { missingMethod ('foo'); }
''';
      final result = await compiler.compile(code);
      expect(result.problems, hasLength(1));
      expect(result.problems.single.message,
          contains("Error when reading 'http://example.com'"));
    });

    test('multiple bad imports', () async {
      const code = '''
import 'package:foo';
import 'package:bar';
''';
      final result = await compiler.compile(code);
      expect(result.problems, hasLength(1));
      expect(result.problems.single.message,
          contains("Invalid package URI 'package:foo'"));
      expect(result.problems.single.message,
          contains("Invalid package URI 'package:bar'"));
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
  });
}
