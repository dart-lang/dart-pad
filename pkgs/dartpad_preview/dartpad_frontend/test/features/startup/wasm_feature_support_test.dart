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
