// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_ui/samples.g.dart';
import 'package:test/test.dart';

void main() {
  group('samples', () {
    test('has dart default', () {
      final sample = Samples.getDefault(type: 'dart');
      expect(sample, isNotNull);
    });

    test('has flutter default', () {
      final sample = Samples.getDefault(type: 'flutter');
      expect(sample, isNotNull);
    });
  });
}
