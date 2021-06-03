// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_services/src/project.dart' as project;
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  for (final nullSafety in [false, true]) {
    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} FlutterWebManager', () {
      final dartHtmlImport = _FakeImportDirective('dart:html');
      final dartUiImport = _FakeImportDirective('dart:ui');
      final packageFlutterImport = _FakeImportDirective('package:flutter/');

      test('inited', () async {
        expect(
            await project.flutterTemplateProject(nullSafety).exists(), isTrue);
        final file = File(path.join(
            project.flutterTemplateProject(nullSafety).path,
            '.dart_tool',
            'package_config.json'));
        expect(await file.exists(), isTrue);
      });

      test('usesFlutterWeb', () {
        expect(project.usesFlutterWeb({_FakeImportDirective('')}), isFalse);
        expect(project.usesFlutterWeb({dartHtmlImport}), isFalse);
        expect(project.usesFlutterWeb({dartUiImport}), isTrue);
        expect(project.usesFlutterWeb({packageFlutterImport}), isTrue);
      });

      test('getUnsupportedImport allows dart:html', () {
        expect(
            project.getUnsupportedImports([_FakeImportDirective('dart:html')]),
            isEmpty);
      });

      test('getUnsupportedImport allows dart:ui', () {
        expect(project.getUnsupportedImports([dartUiImport]), isEmpty);
      });

      test('getUnsupportedImport allows package:flutter', () {
        expect(project.getUnsupportedImports([packageFlutterImport]), isEmpty);
      });

      test('getUnsupportedImport allows package:path', () {
        final packagePathImport = _FakeImportDirective('package:path');
        expect(project.getUnsupportedImports([packagePathImport]), isEmpty);
      });

      test('getUnsupportedImport does now allow package:unsupported', () {
        final usupportedPackageImport =
            _FakeImportDirective('package:unsupported');
        expect(project.getUnsupportedImports([usupportedPackageImport]),
            contains(usupportedPackageImport));
      });

      test('getUnsupportedImport does now allow local imports', () {
        final localFooImport = _FakeImportDirective('foo.dart');
        expect(project.getUnsupportedImports([localFooImport]),
            contains(localFooImport));
      });

      test('getUnsupportedImport does not allow VM-only imports', () {
        final dartIoImport = _FakeImportDirective('dart:io');
        expect(project.getUnsupportedImports([dartIoImport]),
            contains(dartIoImport));
      });
    });

    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} project inited', () {
      test('packagesFilePath', () async {
        final packageConfig = File(path.join(
            project.flutterTemplateProject(nullSafety).path,
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
        final summaryFilePath = project.summaryFilePath(nullSafety);
        expect(summaryFilePath, isNotEmpty);

        final file = File(summaryFilePath);
        expect(file.existsSync(), isTrue);
      });
    });
  }
}

class _FakeImportDirective implements ImportDirective {
  @override
  final _FakeStringLiteral uri;

  _FakeImportDirective(String uri) : uri = _FakeStringLiteral(uri);

  @override
  dynamic noSuchMethod(_) => throw UnimplementedError();
}

class _FakeStringLiteral implements StringLiteral {
  @override
  final String stringValue;

  _FakeStringLiteral(this.stringValue);

  @override
  dynamic noSuchMethod(_) => throw UnimplementedError();
}
