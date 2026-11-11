// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/startup/wasm_feature_support.dart';
import 'package:test/test.dart';

void main() {
  group('missingWasmFeatures', () {
    test('reports no missing features in the test browser', () {
      // The test browser is a current Chrome, which supports every feature
      // the DartPad worker needs.
      expect(missingWasmFeatures(), isEmpty);
    });
  });

  group('isFirefoxBelowMinVersion', () {
    test('matches Firefox older than 147', () {
      const userAgent = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 14.0; rv:146.0) Gecko/20100101 Firefox/146.0';
      expect(isFirefoxBelowMinVersion(userAgent), isTrue);
    });

    test('accepts Firefox 147 and later', () {
      const userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:147.0) Gecko/20100101 Firefox/147.0';
      expect(isFirefoxBelowMinVersion(userAgent), isFalse);
    });

    test('ignores other browsers', () {
      const chrome =
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36';
      const firefoxIos =
          'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) FxiOS/140.0 Mobile/15E148 Safari/605.1.15';
      expect(isFirefoxBelowMinVersion(chrome), isFalse);
      expect(isFirefoxBelowMinVersion(firefoxIos), isFalse);
    });
  });

  group('unsupportedBrowserMessage', () {
    test('lists each missing feature', () {
      expect(
        unsupportedBrowserMessage(['WasmGC', 'JSTag']),
        'This browser does not support WebAssembly features DartPad needs '
        '(WasmGC, JSTag). Use a recent version of Chrome, Edge, Firefox or Safari.',
      );
    });
  });
}
