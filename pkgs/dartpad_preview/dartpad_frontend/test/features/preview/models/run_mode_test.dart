// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:test/test.dart';

void main() {
  group('RunMode', () {
    test('defines mode property matching sandbox protocol identifiers', () {
      expect(RunMode.console.mode, 'console');
      expect(RunMode.flutter.mode, 'flutter');
    });
  });
}
