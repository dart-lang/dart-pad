// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/app_bar.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('disables sample menus while workspace initialization is pending', (
    tester,
  ) {
    tester.pumpComponent(const AppBar());

    final create =
        web.document.querySelector(
              '[aria-label="Create a new snippet"]',
            )!
            as web.HTMLButtonElement;
    final examples = web.document.querySelector('[aria-label="Examples"]')! as web.HTMLButtonElement;
    expect(create.disabled, isTrue);
    expect(examples.disabled, isTrue);
  });

  testClient('opens Create and selects a snippet', (tester) async {
    String? selectedSampleId;
    tester.pumpComponent(
      AppBar(onCreateSample: (sample) => selectedSampleId = sample.id),
    );

    final create =
        web.document.querySelector(
              '[aria-label="Create a new snippet"]',
            )!
            as web.HTMLButtonElement;
    expect(create.disabled, isFalse);

    create.click();
    await pumpEventQueue();
    final items = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-item');
    expect(items.length, 2);
    (items.item(0)! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(selectedSampleId, 'dart');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });

  testClient('opens Examples and selects Fibonacci', (tester) async {
    String? selectedSampleId;
    tester.pumpComponent(
      AppBar(onSelectExample: (sample) => selectedSampleId = sample.id),
    );

    final examples = web.document.querySelector('[aria-label="Examples"]')! as web.HTMLButtonElement;
    expect(examples.disabled, isFalse);

    examples.click();
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-item');
    expect(items.length, greaterThan(0));
    (items.item(0)! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(selectedSampleId, 'fibonacci');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });
}
