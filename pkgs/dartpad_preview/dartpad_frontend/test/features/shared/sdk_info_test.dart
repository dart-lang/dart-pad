// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';

void main() {
  group('SdkInfo', () {
    test('parses Flutter SDK info from JSON', () {
      final sdk = SdkInfo.fromJson({
        'id': 'flutter',
        'name': 'Flutter',
        'path': 'dartpad/flutter/',
        'dartVersion': '3.14.0',
        'flutterVersion': '3.48.0',
      });

      expect(sdk, isNotNull);
      expect(sdk!.id, 'flutter');
      expect(sdk.name, 'Flutter');
      expect(sdk.path, 'dartpad/flutter/');
      expect(sdk.dartVersion, '3.14.0');
      expect(sdk.flutterVersion, '3.48.0');
      expect(sdk.isFlutter, isTrue);
      expect(sdk.displayName, 'Flutter 3.48.0 • Dart 3.14.0');
      expect(sdk.label, 'Flutter (3.48.0)');
    });

    test('parses pure Dart SDK info from JSON', () {
      final sdk = SdkInfo.fromJson({
        'id': 'dart',
        'name': 'Dart',
        'path': 'dartpad/dart/',
        'dartVersion': '3.14.0-edge',
      });

      expect(sdk, isNotNull);
      expect(sdk!.id, 'dart');
      expect(sdk.name, 'Dart');
      expect(sdk.isFlutter, isFalse);
      expect(sdk.flutterVersion, isNull);
      expect(sdk.displayName, 'Dart 3.14.0-edge');
      expect(sdk.label, 'Dart (3.14.0-edge)');
    });

    test('returns null for invalid JSON', () {
      expect(SdkInfo.fromJson({'id': 'flutter'}), isNull);
    });
  });

  group('generated SDK manifest', () {
    test('contains available SDKs with a valid default SDK', () {
      expect(availableSdks, isNotEmpty);
      expect(defaultSdk, isNotNull);
      expect(availableSdks.contains(defaultSdk), isTrue);
    });
  });
}
