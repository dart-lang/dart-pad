// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  for (final nullSafety in [false, true]) {
    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} FlutterWebManager', () {
      FlutterWebManager flutterWebManager;

      final dartHtmlImport = _FakeImportDirective('dart:html');
      final dartUiImport = _FakeImportDirective('dart:ui');
      final packageFlutterImport = _FakeImportDirective('package:flutter/');

      setUp(() async {
        flutterWebManager = FlutterWebManager();
      });

      test('inited', () async {
        expect(
            await FlutterWebManager.flutterTemplateProject(nullSafety).exists(),
            isTrue);
        final file = File(path.join(
            FlutterWebManager.flutterTemplateProject(nullSafety).path,
            '.dart_tool',
            'package_config.json'));
        expect(await file.exists(), isTrue);
      });

      test('usesFlutterWeb', () {
        expect(flutterWebManager.usesFlutterWeb({_FakeImportDirective('')}),
            isFalse);
        expect(flutterWebManager.usesFlutterWeb({dartHtmlImport}), isFalse);
        expect(flutterWebManager.usesFlutterWeb({dartUiImport}), isTrue);
        expect(
            flutterWebManager.usesFlutterWeb({packageFlutterImport}), isTrue);
      });

      test('getUnsupportedImport', () {
        expect(
            flutterWebManager
                .getUnsupportedImports([_FakeImportDirective('dart:html')]),
            isEmpty);
        expect(
            flutterWebManager.getUnsupportedImports([dartUiImport]), isEmpty);
        expect(flutterWebManager.getUnsupportedImports([packageFlutterImport]),
            isEmpty);
        final packagePathImport = _FakeImportDirective('package:path');
        expect(flutterWebManager.getUnsupportedImports([packagePathImport]),
            contains(packagePathImport));
        final localFooImport = _FakeImportDirective('foo.dart');
        expect(flutterWebManager.getUnsupportedImports([localFooImport]),
            contains(localFooImport));
        // dart:io is an unsupported package.
        final dartIoImport = _FakeImportDirective('dart:io');
        expect(flutterWebManager.getUnsupportedImports([dartIoImport]),
            contains(dartIoImport));
      });
    });

    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} FlutterWebManager inited',
        () {
      FlutterWebManager flutterWebManager;

      setUpAll(() async {
        flutterWebManager = FlutterWebManager();
      });

      test('packagesFilePath', () async {
        final packageConfig = File(path.join(
            FlutterWebManager.flutterTemplateProject(nullSafety).path,
            '.dart_tool',
            'package_config.json'));
        expect(await packageConfig.exists(), true);
        final contents = jsonDecode(await packageConfig.readAsString());
        expect(contents['packages'], isNotEmpty);
        expect(
            (contents['packages'] as List)
                .where((element) => element['name'] == 'flutter'),
            isNotEmpty);
      });

      test('summaryFilePath', () {
        final summaryFilePath = flutterWebManager.summaryFilePath(nullSafety);
        expect(summaryFilePath, isNotEmpty);

        final file = File(summaryFilePath);
        expect(file.existsSync(), isTrue);
      });
    });
  }
}

class _FakeImportDirective implements ImportDirective {
  final _FakeStringLiteral uri;

  _FakeImportDirective(String uri) : uri = _FakeStringLiteral(uri);

  dynamic noSuchMethod(_) => throw UnimplementedError();
}

class _FakeStringLiteral implements StringLiteral {
  final String stringValue;

  _FakeStringLiteral(this.stringValue);

  dynamic noSuchMethod(_) => throw UnimplementedError();
}
