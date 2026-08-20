// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/app_bar.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('disables example menus while workspace initialization is pending', (
    tester,
  ) {
    tester.pumpComponent(const AppBar());

    final create =
        web.document.querySelector(
              '[aria-label="Create a new snippet"]',
            )!
            as web.HTMLButtonElement;
    final samples = web.document.querySelector('[aria-label="Samples"]')! as web.HTMLButtonElement;
    expect(create.disabled, isTrue);
    expect(samples.disabled, isTrue);
  });

  testClient('opens Create and selects a snippet', (tester) async {
    String? selectedExampleId;
    tester.pumpComponent(
      AppBar(onCreateNewSnippet: (example) => selectedExampleId = example.id),
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

    expect(selectedExampleId, 'dart');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });

  testClient('opens Samples and selects Fibonacci', (tester) async {
    String? selectedExampleId;
    tester.pumpComponent(
      AppBar(onLoadSample: (example) => selectedExampleId = example.id),
    );

    final samples = web.document.querySelector('[aria-label="Samples"]')! as web.HTMLButtonElement;
    expect(samples.disabled, isFalse);

    samples.click();
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-item');
    expect(items.length, greaterThan(0));
    (items.item(0)! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(selectedExampleId, 'fibonacci');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });

  testClient('renders desktop layout with button labels and without mobile tabs', (tester) {
    tester.pumpComponent(const AppBar(isMobile: false));

    final labels = web.document.querySelectorAll('.app-bar-button-label');
    expect(labels.length, 2);
    expect((labels.item(0)! as web.HTMLElement).textContent, 'Create');
    expect((labels.item(1)! as web.HTMLElement).textContent, 'Examples');

    final mobileTabs = web.document.querySelector('.app-bar-tab-bar');
    expect(mobileTabs, isNull);
  });

  testClient('renders mobile layout without button labels and with mobile tabs', (tester) async {
    int? activeTab;
    tester.pumpComponent(
      AppBar(
        isMobile: true,
        selectedTab: 0,
        onTabSelected: (tab) => activeTab = tab,
      ),
    );

    final labels = web.document.querySelectorAll('.app-bar-button-label');
    expect(labels.length, 0);

    final mobileTabs = web.document.querySelector('.app-bar-tab-bar');
    expect(mobileTabs, isNotNull);

    final tabs = web.document.querySelectorAll('.app-bar-tab');
    expect(tabs.length, 2);
    expect((tabs.item(0)! as web.HTMLButtonElement).textContent, 'Code');
    expect((tabs.item(0)! as web.HTMLButtonElement).classList.contains('active'), isTrue);
    expect((tabs.item(1)! as web.HTMLButtonElement).textContent, 'Output');
    expect((tabs.item(1)! as web.HTMLButtonElement).classList.contains('active'), isFalse);

    (tabs.item(1)! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(activeTab, 1);
  });

  testClient('renders nothing in desktop embed mode', (tester) {
    tester.pumpComponent(const AppBar(isMobile: false, isEmbedMode: true));

    expect(web.document.querySelector('.app-bar'), isNull);
    expect(web.document.querySelector('.app-bar-tab-bar'), isNull);
  });

  testClient('renders only tab bar in mobile embed mode', (tester) {
    tester.pumpComponent(const AppBar(isMobile: true, isEmbedMode: true));

    expect(web.document.querySelector('.app-bar'), isNull);
    expect(web.document.querySelector('.app-bar-tab-bar'), isNotNull);

    final tabs = web.document.querySelectorAll('.app-bar-tab');
    expect(tabs.length, 2);
  });
}


