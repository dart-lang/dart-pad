// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/app_bar.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('disables Create while workspace initialization is pending', (
    tester,
  ) {
    tester.pumpComponent(const AppBar());

    final create =
        web.document.querySelector(
              '[aria-label="Create a new snippet"]',
            )!
            as web.HTMLButtonElement;
    expect(create.disabled, isTrue);
  });

  testClient('enables Create when workspace initialization completes', (
    tester,
  ) async {
    var createCalls = 0;
    tester.pumpComponent(AppBar(onCreateNew: () => createCalls++));

    final create =
        web.document.querySelector(
              '[aria-label="Create a new snippet"]',
            )!
            as web.HTMLButtonElement;
    expect(create.disabled, isFalse);

    create.click();
    await pumpEventQueue();
    expect(createCalls, 1);
  });
}
