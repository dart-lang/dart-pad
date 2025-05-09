// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_ui/samples.g.dart';
import 'package:test/test.dart';

void main() {
  group('samples', () {
    test('has default dart sample', () {
      final sample = Samples.getById('dart');
      expect(sample, isNotNull);
    });

    test('has default flutter sample', () {
      final sample = Samples.getById('flutter');
      expect(sample, isNotNull);
    });
  });
}
