// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_ui/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'test_infra/test_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Initial screen.', (WidgetTester tester) async {
    await setMinLargeScreenWidth(tester);

    await tester.pumpWidget(const DartPadApp());
    await waitForRequestsToComplete(tester);

    await expectLater(
      find.byType(DartPadApp),
      matchesGoldenFile('$goldenPath/main_DartPadApp.png'),
    );
  });
}
