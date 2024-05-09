// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_ui/model.dart';
import 'package:test/test.dart';

void main() {
  group('Channel', () {
    test('master is aliased', () {
      final value = Channel.forName('master');
      expect(value?.name, 'main');
    });

    test('supported channels', () {
      final result = Channel.valuesWithoutLocalhost.map((c) => c.name).toList();
      expect(
        result,
        unorderedMatches(
          [
            'main',
            'beta',
            'stable',
          ],
        ),
      );
    });
  });
}
