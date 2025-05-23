// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_infra/test_utils.dart';

void main() {
  setUpAll(() async {
    await TestServerRunner().maybeStart();
  });

  testWidgets('AI CUJ', (WidgetTester tester) async {
    await initializeMainPage(tester);
    await tester.tap(find.text('Create with Gemini'));
    await tester.pump();
    await tester.tap(find.text('Flutter Snippet'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('to-do app'));
    await tester.pump();
    await tester.tap(find.text('Generate'));
    await tester.pumpAndSettle();
    expect(
      find.text('Placeholder for HtmlElementView, available on web only.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Accept'));
  });
}
