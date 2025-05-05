// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:ui';

import 'package:dartpad_ui/main.dart';
import 'package:flutter_test/flutter_test.dart';

const goldenPath = 'test/test_infra/goldens';

/// Sets the window size to be smallest possible for a large screen.
///
/// Needed to test there is no overflow on almost small screens.
Future<void> setMinLargeScreenWidth(WidgetTester tester) async {
  // We need to add some width to avoid overflow
  // in tests, while overflow is not happening in real app on web and on mac.
  const screenWidthDelta = 650;
  await tester.binding.setSurfaceSize(
    const Size(
      minLargeScreenWidth + screenWidthDelta,
      minLargeScreenWidth * 0.7,
    ),
  );
  addTearDown(() => tester.binding.setSurfaceSize(null));
}
