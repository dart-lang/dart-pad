// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main application bar with the DartPad logo, title, theme toggle, and
/// overflow menu.
class AppBar extends StatefulComponent {
  const AppBar({super.key});

  @override
  State<AppBar> createState() => _AppBarState();

  @css
  static List<StyleRule> get styles => _AppBarState.styles;
}

class _AppBarState extends State<AppBar> {
  void _openLink(String uri) {
    web.window.open(uri, '_blank');
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-bar', [
      // Left section: logo + title.
      const div(classes: 'app-bar-left', [
        img(
          src: 'images/dart_logo_192.png',
          alt: 'Dart',
          classes: 'app-bar-logo',
        ),
        span(classes: 'app-bar-title', [.text('DartPad')]),
      ]),
      // Spacer.
      const div(classes: 'app-bar-spacer', []),
      // Right section: theme toggle + overflow menu.
      div(classes: 'app-bar-right', [
        const ThemeToggle(),
        DropdownMenu(
          trigger: const dp.IconButton(
            icon: 'more_vert',
            tooltip: 'More options',
            label: 'More options',
          ),
          items: [
            DropdownMenuItem(
              label: 'Install SDK',
              trailingIcon: 'launch',
              onPressed: () => _openLink('https://flutter.dev/get-started'),
            ),
            DropdownMenuItem(
              label: 'Sharing guide',
              trailingIcon: 'launch',
              onPressed: () => _openLink(
                'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
              ),
            ),
          ],
        ),
      ]),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.app-bar').styles(
      display: .flex,
      height: 48.px,
      minHeight: 48.px,
      padding: .symmetric(horizontal: 12.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 2.px),
      ),
      alignItems: .center,
      gap: Gap.all(8.px),
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.app-bar-left').styles(
      display: .flex,
      alignItems: .center,
      gap: Gap.all(8.px),
    ),
    css('.app-bar-spacer').styles(
      flex: const Flex(grow: 1),
    ),
    css('.app-bar-right').styles(
      display: .flex,
      alignItems: .center,
      gap: Gap.all(4.px),
    ),
    css('.app-bar-logo').styles(
      width: 24.px,
      height: 24.px,
    ),
    css('.app-bar-title').styles(
      fontSize: 16.px,
      fontWeight: .w600,
      letterSpacing: const .em(0.02),
    ),
  ];
}
