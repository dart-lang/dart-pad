// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/editor/components/small_screen_tab_bar.dart';
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

  testClient('renders logo and DartPad title', (tester) {
    tester.pumpComponent(const AppBar());

    final logo = web.document.querySelector('.app-bar-logo') as web.HTMLImageElement?;
    expect(logo, isNotNull);
    expect(logo!.src, contains('images/dart_logo_192.png'));
    expect(logo.alt, 'Dart');

    final title = web.document.querySelector('.app-bar-title');
    expect(title, isNotNull);
    expect(title!.textContent, 'DartPad');
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

  testClient('renders AppBar with button labels and without SmallScreenTabBar on large screens', (tester) {
    tester.pumpComponent(const AppBar());

    final labels = web.document.querySelectorAll('.app-bar-button-label');
    expect(labels.length, 2);
    expect((labels.item(0)! as web.HTMLElement).textContent, 'Create');
    expect((labels.item(1)! as web.HTMLElement).textContent, 'Samples');

    final smallScreenTabBar = web.document.querySelector('.small-screen-tab-bar');
    expect(smallScreenTabBar, isNull);
  });

  testClient('renders AppBar and SmallScreenTabBar on small screens', (tester) {
    tester.pumpComponent(
      AppBar(
        smallScreenTabBar: SmallScreenTabBar(onTabSelected: (_) {}),
      ),
    );

    final labels = web.document.querySelectorAll('.app-bar-button-label');
    expect(labels.length, 0);

    final smallScreenTabBar = web.document.querySelector('.small-screen-tab-bar');
    expect(smallScreenTabBar, isNotNull);
  });

  testClient('renders nothing in large-screen embed mode', (tester) {
    tester.pumpComponent(const AppBar(isEmbedMode: true));

    expect(web.document.querySelector('.app-bar'), isNull);
    expect(web.document.querySelector('.small-screen-tab-bar'), isNull);
  });

  testClient('renders only SmallScreenTabBar in small-screen embed mode', (tester) {
    var selectedTab = SmallScreenTab.code;
    tester.pumpComponent(
      AppBar(
        isEmbedMode: true,
        smallScreenTabBar: SmallScreenTabBar(
          onTabSelected: (tab) => selectedTab = tab,
        ),
      ),
    );

    expect(web.document.querySelector('.app-bar'), isNull);
    expect(web.document.querySelector('.small-screen-tab-bar'), isNotNull);

    final tabs = web.document.querySelectorAll('.small-screen-tab-bar-tab');
    expect(tabs.length, 2);
    (tabs.item(1)! as web.HTMLButtonElement).click();
    expect(selectedTab, SmallScreenTab.output);
  });
}
