// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter_test/flutter_test.dart';

// TODO(polina-ch): Remove this test when we have alerting setup.
void main() {
  testWidgets(
    'This test is designed to fail to ensure we have alerting setup.',
    (WidgetTester tester) async {
      expect(false, true);
    },
  );
}
