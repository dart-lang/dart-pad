// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:dart_services/src/project.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  final projectTemplates = ProjectTemplates.projectTemplates;

  group('FlutterWebManager', () {
    final dartHtmlImport = _FakeImportDirective('dart:html');
    final dartUiImport = _FakeImportDirective('dart:ui');
    final packageFlutterImport = _FakeImportDirective('package:flutter/');

    test('inited', () async {
      expect(await Directory(projectTemplates.flutterPath).exists(), isTrue);
      final file = File(path.join(
          projectTemplates.flutterPath, '.dart_tool', 'package_config.json'));
      expect(await file.exists(), isTrue);
    });

    test('usesFlutterWeb', () {
      expect(
          usesFlutterWeb({_FakeImportDirective('')}, devMode: false), isFalse);
      expect(usesFlutterWeb({dartHtmlImport}, devMode: false), isFalse);
      expect(usesFlutterWeb({dartUiImport}, devMode: false), isTrue);
      expect(usesFlutterWeb({packageFlutterImport}, devMode: false), isTrue);
    });

    test('getUnsupportedImport allows current library import', () {
      expect(getUnsupportedImports([_FakeImportDirective('')], devMode: false),
          isEmpty);
    });

    test('getUnsupportedImport allows dart:html', () {
      expect(
          getUnsupportedImports([_FakeImportDirective('dart:html')],
              devMode: false),
          isEmpty);
    });

    test('getUnsupportedImport allows dart:ui', () {
      expect(getUnsupportedImports([dartUiImport], devMode: false), isEmpty);
    });

    test('getUnsupportedImport allows package:flutter', () {
      expect(getUnsupportedImports([packageFlutterImport], devMode: false),
          isEmpty);
    });

    test('getUnsupportedImport allows package:path', () {
      final packagePathImport = _FakeImportDirective('package:path');
      expect(
          getUnsupportedImports([packagePathImport], devMode: false), isEmpty);
    });

    test('getUnsupportedImport does now allow package:unsupported', () {
      final usupportedPackageImport =
          _FakeImportDirective('package:unsupported');
      expect(getUnsupportedImports([usupportedPackageImport], devMode: false),
          contains(usupportedPackageImport));
    });

    test('getUnsupportedImport does now allow local imports', () {
      final localFooImport = _FakeImportDirective('foo.dart');
      expect(getUnsupportedImports([localFooImport], devMode: false),
          contains(localFooImport));
    });

    test('getUnsupportedImport does not allow VM-only imports', () {
      final dartIoImport = _FakeImportDirective('dart:io');
      expect(getUnsupportedImports([dartIoImport], devMode: false),
          contains(dartIoImport));
    });
  });

  group('project inited', () {
    test('packagesFilePath', () async {
      final packageConfig = File(path.join(
          projectTemplates.flutterPath, '.dart_tool', 'package_config.json'));
      expect(await packageConfig.exists(), true);
      final encoded = await packageConfig.readAsString();
      final contents = jsonDecode(encoded) as Map<String, dynamic>;
      expect(contents['packages'], isNotEmpty);
      final packages = contents['packages'] as List<dynamic>;
      expect(packages.where((element) => (element as Map)['name'] == 'flutter'),
          isNotEmpty);
    });

    test('summaryFilePath', () {
      final summaryFilePath = projectTemplates.summaryFilePath;
      expect(summaryFilePath, isNotEmpty);

      final file = File(summaryFilePath);
      expect(file.existsSync(), isTrue);
    });
  });
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
