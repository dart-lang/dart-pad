// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('FlutterWebManager', () {
    FlutterWebManager flutterWebManager;

    setUp(() async {
      await SdkManager.sdk.init();
      await SdkManager.flutterSdk.init();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
    });

    tearDown(() {
      flutterWebManager.dispose();
    });

    test('inited', () {
      expect(flutterWebManager.projectDirectory.existsSync(), isTrue);
      final file = File(flutterWebManager.packagesFilePath);
      expect(file.existsSync(), isTrue);
    });

    test('usesFlutterWeb', () {
      expect(flutterWebManager.usesFlutterWeb({''}), isFalse);
      expect(flutterWebManager.usesFlutterWeb({'dart:html'}), isFalse);
      expect(flutterWebManager.usesFlutterWeb({'dart:ui'}), isTrue);
      expect(flutterWebManager.usesFlutterWeb({'package:flutter_web'}), isTrue);
      expect(
          flutterWebManager.usesFlutterWeb({'package:flutter_web/'}), isTrue);
    });

    test('getUnsupportedImport', () {
      expect(flutterWebManager.getUnsupportedImport({'dart:html'}), isNull);
      expect(flutterWebManager.getUnsupportedImport({'dart:ui'}), isNull);
      expect(flutterWebManager.getUnsupportedImport({'package:flutter_web/'}),
          isNull);
      expect(flutterWebManager.getUnsupportedImport({'package:path'}),
          equals('package:path'));
      expect(flutterWebManager.getUnsupportedImport({'foo.dart'}),
          equals('foo.dart'));
    });
  });

  group('FlutterWebManager package:flutter_web inited', () {
    FlutterWebManager flutterWebManager;

    setUpAll(() async {
      await SdkManager.sdk.init();
      await SdkManager.flutterSdk.init();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      await flutterWebManager.initFlutterWeb();
    });

    tearDownAll(() {
      flutterWebManager.dispose();
    });

    test('packagesFilePath', () {
      final packagesPath = flutterWebManager.packagesFilePath;
      expect(packagesPath, isNotEmpty);

      final file = File(packagesPath);
      final lines = file.readAsLinesSync();
      expect(lines, anyElement(startsWith('flutter:file://')));
    });

    test('summaryFilePath', () {
      final summaryFilePath = flutterWebManager.summaryFilePath;
      expect(summaryFilePath, isNotEmpty);

      final file = File(summaryFilePath);
      expect(file.existsSync(), isTrue);
    });
  });
}
