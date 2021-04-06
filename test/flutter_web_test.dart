// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_services/src/flutter_web.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('FlutterWebManager', () {
    FlutterWebManager flutterWebManager;

    setUp(() async {
      flutterWebManager = FlutterWebManager();
    });

    test('inited', () async {
      expect(await FlutterWebManager.flutterTemplateProject.exists(), isTrue);
      final file = File(path.join(FlutterWebManager.flutterTemplateProject.path,
          '.dart_tool', 'package_config.json'));
      expect(await file.exists(), isTrue);
    });

    test('usesFlutterWeb', () {
      expect(flutterWebManager.usesFlutterWeb({''}), isFalse);
      expect(flutterWebManager.usesFlutterWeb({'dart:html'}), isFalse);
      expect(flutterWebManager.usesFlutterWeb({'dart:ui'}), isTrue);
      expect(flutterWebManager.usesFlutterWeb({'package:flutter'}), isTrue);
      expect(flutterWebManager.usesFlutterWeb({'package:flutter/'}), isTrue);
    });

    test('getUnsupportedImport', () {
      expect(flutterWebManager.getUnsupportedImport({'dart:html'}), isNull);
      expect(flutterWebManager.getUnsupportedImport({'dart:ui'}), isNull);
      expect(
          flutterWebManager.getUnsupportedImport({'package:flutter/'}), isNull);
      expect(flutterWebManager.getUnsupportedImport({'package:path'}),
          equals('package:path'));
      expect(flutterWebManager.getUnsupportedImport({'foo.dart'}),
          equals('foo.dart'));
      // dart:io is an unsupported package
      expect(flutterWebManager.getUnsupportedImport({'dart:io'}),
          equals('dart:io'));
    });
  });

  group('FlutterWebManager inited', () {
    FlutterWebManager flutterWebManager;

    setUpAll(() async {
      flutterWebManager = FlutterWebManager();
    });

    test('packagesFilePath', () async {
      final packageConfig = File(path.join(
          FlutterWebManager.flutterTemplateProject.path,
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
      final summaryFilePath = flutterWebManager.summaryFilePath;
      expect(summaryFilePath, isNotEmpty);

      final file = File(summaryFilePath);
      expect(file.existsSync(), isTrue);
    });
  });
}
