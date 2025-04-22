// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/services.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenPath = 'test_infra/goldens/';

/// Waits for all active HTTP requests to complete.
Future<void> waitForRequestsToComplete(WidgetTester tester) async {
  while (activeHttpRequests > 0) {
    await tester.pumpAndSettle();
  }
}
