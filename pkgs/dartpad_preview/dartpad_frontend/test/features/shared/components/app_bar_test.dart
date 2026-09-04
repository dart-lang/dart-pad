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
  testClient('disables example menu while workspace initialization is pending', (
    tester,
  ) {
    tester.pumpComponent(const AppBar());

    final newButton =
        web.document.querySelector(
              '[aria-label="New"]',
            )!
            as web.HTMLButtonElement;
    expect(newButton.disabled, isTrue);
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

  testClient('opens New and selects Dart Snippet', (tester) async {
    String? selectedExampleId;
    tester.pumpComponent(
      AppBar(onSelectExample: (example) => selectedExampleId = example.id),
    );

    final newButton =
        web.document.querySelector(
              '[aria-label="New"]',
            )!
            as web.HTMLButtonElement;
    expect(newButton.disabled, isFalse);

    newButton.click();
    await pumpEventQueue();
    final items = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-item');
    expect(items.length, 6);
    (items.item(0)! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(selectedExampleId, 'dart');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });

  testClient('opens New and selects Fibonacci with section dividers', (tester) async {
    String? selectedExampleId;
    tester.pumpComponent(
      AppBar(onSelectExample: (example) => selectedExampleId = example.id),
    );

    final newButton =
        web.document.querySelector(
              '[aria-label="New"]',
            )!
            as web.HTMLButtonElement;
    expect(newButton.disabled, isFalse);

    newButton.click();
    await pumpEventQueue();

    final dividers = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-divider');
    expect(dividers.length, 2);
    expect((dividers.item(0)! as web.HTMLElement).textContent, 'Dart');
    expect((dividers.item(1)! as web.HTMLElement).textContent, 'Flutter');

    final items = web.document.querySelectorAll('.dropdown-menu-panel-left .dropdown-menu-item');
    expect(items.length, 6);
    (items.item(2)! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(selectedExampleId, 'fibonacci');
    expect(web.document.querySelector('.dropdown-menu-panel-left'), isNull);
  });

  testClient('renders AppBar with button label and without SmallScreenTabBar on large screens', (tester) {
    tester.pumpComponent(const AppBar());

    final labels = web.document.querySelectorAll('.app-bar-button-label');
    expect(labels.length, 1);
    expect((labels.item(0)! as web.HTMLElement).textContent, 'New');

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
