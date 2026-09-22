// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';

/// A real browser worker with a minimal protocol, without the SDK or analyzer.
final class TestWorker {
  TestWorker._(this.dartpad) {
    dartpad.done.then((_) => isClosed = true);
  }

  final DartPad dartpad;
  bool isClosed = false;

  static late final Uri _assetBaseUrl;

  /// Capture the test server prefix before Jaspr tests change the page URL.
  static void captureAssetBaseUrl() {
    _assetBaseUrl = Uri.base.resolve('../../fixtures/worker/');
  }

  static Future<TestWorker> start() async {
    return TestWorker._(await DartPadSdk(assetBaseUrl: _assetBaseUrl).dedicatedWorker());
  }

  Future<void> dispose() => dartpad.dispose();
}
