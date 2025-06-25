// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:dartpad_ui/app/genai_editing.dart';
import 'package:dartpad_ui/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_infra/test_utils.dart';

void main() {
  setUpAll(() async {
    await TestServerRunner().maybeStart();
  });

  testWidgets('Initial screen.', (WidgetTester tester) async {
    await setMinLargeScreenWidth(tester);

    await tester.pumpWidget(const DartPadApp(channel: 'localhost'));

    final DartPadMainPageState state = tester.state(
      find.byType(DartPadMainPage),
    );

    await state.initialized.future;
    await tester.pumpAndSettle();
    await expectLater(find.byType(EditorWithButtons), findsOneWidget);

    await expectLater(
      find.byType(DartPadApp),
      matchesGoldenFile('$goldenPath/main_screen_initial.png'),
    );
  });
}
