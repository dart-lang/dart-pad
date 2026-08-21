// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';
import 'dropdown_menu.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main application bar with the DartPad logo, title, theme toggle, and
/// overflow menu.
class AppBar extends StatefulComponent {
  const AppBar({this.onCreateNew, super.key});

  /// Called when the user wants to create a new project.
  final VoidCallback? onCreateNew;

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
    final isCreateDisabled = component.onCreateNew == null;
    return div(classes: 'app-bar', [
      // Left section: logo + title + create.
      div(classes: 'app-bar-left', [
        const img(
          src: 'images/dart_logo_192.png',
          alt: 'Dart',
          classes: 'app-bar-logo',
        ),
        const span(classes: 'app-bar-title', [.text('DartPad')]),
        const div(classes: 'app-bar-divider', []),
        button(
          classes: 'app-bar-text-button',
          disabled: isCreateDisabled,
          attributes: {
            'aria-label': 'Create a new snippet',
            'title': 'Create a new snippet',
          },
          onClick: isCreateDisabled
              ? null
              : () {
                  component.onCreateNew?.call();
                },
          [
            const Icon('add_circle', size: 18),
            const span(classes: 'app-bar-button-label', [.text('Create')]),
          ],
        ),
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
    css('.app-bar-divider').styles(
      width: 1.px,
      height: 24.px,
      margin: .symmetric(horizontal: 4.px),
      backgroundColor: colorBorder,
    ),

    // -- Text button (Create) --
    css('.app-bar-text-button').styles(
      display: .flex,
      padding: .symmetric(horizontal: 10.px, vertical: 6.px),
      border: .none,
      radius: .circular(6.px),
      cursor: .pointer,
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnSurface,
      fontSize: 13.px,
      fontWeight: .w500,
      backgroundColor: Colors.transparent,
    ),
    css('.app-bar-text-button:hover').styles(
      backgroundColor: colorBorder,
    ),
    css('.app-bar-text-button:disabled').styles(
      opacity: 0.5,
      cursor: .defaultCursor,
      raw: {'pointer-events': 'none'},
    ),
    css('.app-bar-button-label').styles(
      whiteSpace: .noWrap,
    ),
  ];
}
