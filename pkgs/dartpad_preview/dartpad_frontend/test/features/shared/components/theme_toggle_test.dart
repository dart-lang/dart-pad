// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/theme_toggle.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUp(() {
    web.window.localStorage.removeItem('dartpad:theme');
    web.document.documentElement!.removeAttribute('data-theme');
  });

  testClient('defaults to dark theme if no attribute or localStorage is set', (tester) async {
    tester.pumpComponent(const ThemeToggle());

    // Verify initial attribute on documentElement is dark
    expect(web.document.documentElement!.getAttribute('data-theme'), 'dark');

    // The button icon should be 'light_mode' (since clicking it toggles to light)
    final button = web.document.querySelector('.icon-button')! as web.HTMLButtonElement;
    expect(button.getAttribute('aria-label'), 'Theme Toggle');
    expect(button.textContent, contains('light_mode'));
  });

  testClient('initializes from document element attribute data-theme="light"', (tester) async {
    web.document.documentElement!.setAttribute('data-theme', 'light');

    tester.pumpComponent(const ThemeToggle());

    // Verify attribute on documentElement is light
    expect(web.document.documentElement!.getAttribute('data-theme'), 'light');

    // The button icon should be 'dark_mode'
    final button = web.document.querySelector('.icon-button')! as web.HTMLButtonElement;
    expect(button.textContent, contains('dark_mode'));
  });

  testClient('clicking the toggle switches the theme and stores choice in localStorage', (tester) async {
    tester.pumpComponent(const ThemeToggle());

    final button = web.document.querySelector('.icon-button')! as web.HTMLButtonElement;

    // Initially dark
    expect(web.document.documentElement!.getAttribute('data-theme'), 'dark');
    expect(button.textContent, contains('light_mode'));
    expect(web.window.localStorage.getItem('dartpad:theme'), isNull);

    // Toggle to light
    await tester.click(find.byType(ThemeToggle));

    expect(web.document.documentElement!.getAttribute('data-theme'), 'light');
    expect(button.textContent, contains('dark_mode'));
    expect(web.window.localStorage.getItem('dartpad:theme'), 'light');

    // Toggle back to dark
    await tester.click(find.byType(ThemeToggle));

    expect(web.document.documentElement!.getAttribute('data-theme'), 'dark');
    expect(button.textContent, contains('light_mode'));
    expect(web.window.localStorage.getItem('dartpad:theme'), 'dark');
  });
}
