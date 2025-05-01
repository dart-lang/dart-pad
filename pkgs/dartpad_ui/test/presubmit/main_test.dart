// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:dartpad_shared/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final runner = TestServerRunner();
  late final ServicesClient client;

  setUpAll(() async {
    await runner.start();
    client = runner.client;
    debugPrint('Client: $client');
  });

  tearDownAll(() async {
    await runner.stop();
  });

  testWidgets('Initial screen.', (WidgetTester tester) async {
    // await setMinLargeScreenWidth(tester);

    // await tester.pumpWidget(const DartPadApp(channel: 'localhost'));

    // final DartPadMainPageState state = tester.state(
    //   find.byType(DartPadMainPage),
    // );

    // await state.initialized.future;
    // await tester.pumpAndSettle();
    // await expectLater(find.byType(EditorWithButtons), findsOneWidget);
  });
}
