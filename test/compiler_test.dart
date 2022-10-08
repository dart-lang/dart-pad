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
  const kMainDart = 'main.dart';

  group('(Always) Null Safe Compiler', () {
    late Compiler compiler;

    setUpAll(() async {
      final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;
      compiler = Compiler(Sdk.create(channel));
      await compiler.warmup();
    });

    tearDownAll(() async {
      await compiler.dispose();
    });

    Future<void> Function() generateCompilerFilesTest(
            Map<String, String> files) =>
        () async {
          final result =
              await compiler.compileFiles(files, returnSourceMap: false);
          expect(result.problems, isEmpty);
          expect(result.success, true);
          expect(result.compiledJS, isNotEmpty);

          expect(result.compiledJS, contains('(function dartProgram() {'));
        };

    Future<void> Function() generateCompilerFilesDDCTest(
            Map<String, String> files) =>
        () async {
          final result = await compiler.compileFilesDDC(files);
          expect(result.problems, isEmpty);
          expect(result.success, true);
          expect(result.compiledJS, isNotEmpty);
          expect(result.modulesBaseUrl, isNotEmpty);

          expect(result.compiledJS, contains("define('dartpad_main', ["));
        };

    Future<void> Function() generateCompilerDDCTest(String sample) => () async {
          final result = await compiler.compileDDC(sample);
          expect(result.problems, isEmpty);
          expect(result.success, true);
          expect(result.compiledJS, isNotEmpty);
          expect(result.modulesBaseUrl, isNotEmpty);

          expect(result.compiledJS, contains("define('dartpad_main', ["));
        };

    test('simple', () async {
      final result = await compiler.compile(sampleCode);

      expect(result.problems, isEmpty);
      expect(result.success, true);
      expect(result.compiledJS, isNotEmpty);
      expect(result.sourceMap, isNull);
    });

    test(
      'compileDDC simple',
      generateCompilerDDCTest(sampleCode),
    );

    test(
      'compileDDC with web',
      generateCompilerDDCTest(sampleCodeWeb),
    );

    test(
      'compileDDC with Flutter',
      generateCompilerDDCTest(sampleCodeFlutter),
    );

    test(
      'compileDDC with Flutter Counter',
      generateCompilerDDCTest(sampleCodeFlutterCounter),
    );

    test(
      'compileDDC with Flutter Sunflower',
      generateCompilerDDCTest(sampleCodeFlutterSunflower),
    );

    test(
      'compileDDC with Flutter Draggable Card',
      generateCompilerDDCTest(sampleCodeFlutterDraggableCard),
    );

    test(
      'compileDDC with Flutter Implicit Animations',
      generateCompilerDDCTest(sampleCodeFlutterImplicitAnimations),
    );

    test(
      'compileDDC with async',
      generateCompilerDDCTest(sampleCodeAsync),
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

    //---------------------------------------------------------------
    // Beginning of multi file files={} tests group:

    test(
      'files:{} compileFilesDDC simple',
      generateCompilerFilesDDCTest({kMainDart: sampleCode}),
    );

    test(
      'files:{} compileFilesDDC with web',
      generateCompilerFilesDDCTest({kMainDart: sampleCodeWeb}),
    );

    // Try not using 'main.dart' filename, should be handled OK.
    test(
      'files:{} compileFilesDDC with Flutter',
      generateCompilerFilesDDCTest({'mymainthing.dart': sampleCodeFlutter}),
    );

    // Filename other than 'main.dart'.
    test(
      'files:{} no main.dart (different.dart) compileFilesDDC with Flutter Counter',
      generateCompilerFilesDDCTest(
          {'different.dart': sampleCodeFlutterCounter}),
    );

    // 2 separate files, main importing 'various.dart'.
    test(
      'files:{} compileFilesDDC with 2 files using import',
      generateCompilerFilesDDCTest({
        kMainDart: sampleCode2PartImportMain,
        'various.dart': sampleCode2PartImportVarious
      }),
    );

    // 3 separate files, main importing 'various.dart' and 'discdata.dart',
    // and 'various.dart' importing 'discdata.dart'.
    test(
      'files:{} compileFilesDDC with 3 file using imports',
      generateCompilerFilesDDCTest({
        kMainDart: sampleCode3PartImportMain,
        'discdata.dart': sampleCode3PartImportDiscData,
        'various.dart': sampleCode3PartImportVarious
      }),
    );

    // 2 separate files, main importing 'various.dart' but with
    // up paths in names...test sanitizing filenames of '..\.../..' and '..'
    // santizing should strip off all up dir chars and leave just the
    // plain filenames.
    test(
      'files:{} compileFilesDDC with 2 files and file names sanitized',
      generateCompilerFilesDDCTest({
        '..\\.../../$kMainDart': sampleCode2PartImportMain,
        '../various.dart': sampleCode2PartImportVarious
      }),
    );

    // 2 files using "part 'various.dart'" to bring in second file.
    test(
      'files:{} compileFilesDDC with 2 file using LIBRARY/PART/PART OF',
      generateCompilerFilesDDCTest({
        kMainDart: sampleCode2PartLibraryMain,
        'various.dart': sampleCode2PartVariousAndDiscDataPartOfTestAnim
      }),
    );

    // 3 files using "part 'various.dart'" and "part 'discdata.dart'" to bring
    // in second and third files.
    test(
      'files:{} compileFilesDDC with 3 files using LIBRARY/PART/PART OF',
      generateCompilerFilesDDCTest({
        kMainDart: sampleCode3PartLibraryMain,
        'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
        'various.dart': sampleCode3PartVariousPartOfTestAnim
      }),
    );

    // Check sanitizing of package:, dart:, http:// from filenames.
    test(
      'files:{} compileFilesDDC with 3 SANITIZED files using LIBRARY/PART/PART OF',
      generateCompilerFilesDDCTest({
        'package:$kMainDart': sampleCode3PartLibraryMain,
        'dart:discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
        'http://various.dart': sampleCode3PartVariousPartOfTestAnim
      }),
    );

    // Test renaming the file with the main function ('mymain.dart') to be
    // kMainDart when no file named kMainDart is found.
    test(
      'files:{} compileFilesDDC with 3 files and none named kMainDart',
      generateCompilerFilesDDCTest({
        'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
        'various.dart': sampleCode3PartVariousPartOfTestAnim,
        'mymain.dart': sampleCode3PartLibraryMain
      }),
    );

    // Two separate files, illegal import in second file, test that
    // illegal imports within all files are detected.
    final Map<String, String> filesVar2BadImports = {};
    const String badImports = '''
import 'package:foo';
import 'package:bar';
  ''';
    filesVar2BadImports[kMainDart] = '''
$sampleCode3PartFlutterImplicitAnimationsImports
import 'various.dart';
$sampleCode3PartFlutterImplicitAnimationsMain
  ''';
    filesVar2BadImports['various.dart'] = '''
$sampleCode3PartFlutterImplicitAnimationsImports
$badImports
$sampleCode3PartFlutterImplicitAnimationsDiscData
$sampleCode3PartFlutterImplicitAnimationsVarious
  ''';
    test('multiple files, second file with multiple bad imports compileFiles()',
        () async {
      final result = await compiler.compileFiles(filesVar2BadImports);
      expect(result.problems, hasLength(2));
      expect(result.problems[0].message,
          equals('unsupported import: package:foo'));
      expect(result.problems[1].message,
          equals('unsupported import: package:bar'));
    });
    test(
        'multiple files, second file with multiple bad imports compileFilesDDC()',
        () async {
      final result = await compiler.compileFilesDDC(filesVar2BadImports);
      expect(result.problems, hasLength(2));
      expect(result.problems[0].message,
          equals('unsupported import: package:foo'));
      expect(result.problems[1].message,
          equals('unsupported import: package:bar'));
    });

    //------------------------------------------------------------------
    // Similiar test as above but targeting compileFiles():
    test(
      'files:{} compileFiles simple',
      generateCompilerFilesTest({kMainDart: sampleCode}),
    );

    test(
      'files:{} compileFiles with web',
      generateCompilerFilesTest({kMainDart: sampleCodeWeb}),
    );

    // 2 separate files, main importing 'various.dart'.
    test(
      'files:{} compileFiles with 2 file',
      generateCompilerFilesTest(
          {kMainDart: sampleCodeMultiFoo, 'bar.dart': sampleCodeMultiBar}),
    );

    // 2 separate files, main importing 'various.dart' but with
    // up paths in names...test sanitizing filenames of '..\.../..' and '..'
    // santizing should strip off all up dir chars and leave just the
    // plain filenames.
    test(
      'files:{} compileFiles with 2 files and file names sanitized',
      generateCompilerFilesTest({
        '..\\.../../$kMainDart': sampleCodeMultiFoo,
        '../bar.dart': sampleCodeMultiBar
      }),
    );

    // Using "part 'various.dart'" to bring in second file.
    test(
      'files:{} compileFiles with 2 file using LIBRARY/PART/PART OF',
      generateCompilerFilesTest({
        kMainDart: sampleCodeLibraryMultiFoo,
        'bar.dart': sampleCodePartMultiBar
      }),
    );

    // Check sanitizing of package:, dart:, http:// from filenames.
    test(
      'files:{} compileFiles with 2 sanitized files using LIBRARY/PART/PART OF',
      generateCompilerFilesTest({
        'package:$kMainDart': sampleCodeLibraryMultiFoo,
        'dart:bar.dart': sampleCodePartMultiBar
      }),
    );

    // Test renaming the file with the main function ('mymain.dart') to be
    // kMainDart when no file named kMainDat is found.
    test(
      'files:{} compileFiles with 2 files and none named kMainDart',
      generateCompilerFilesTest(
          {'mymain.dart': sampleCodeMultiFoo, 'bar.dart': sampleCodeMultiBar}),
    );
    // End of multi file files={} map testing.
  });
}
