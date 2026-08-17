// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';
import 'icon_button.dart' as dp;
import 'theme_toggle.dart';

/// The main application bar with the DartPad logo, title, theme toggle, and
/// overflow menu.
///
/// Ported from the Flutter DartPad `DartPadAppBar` widget.
class AppBar extends StatefulComponent {
  const AppBar({super.key});

  @override
  State<AppBar> createState() => _AppBarState();

  @css
  static List<StyleRule> get styles => _AppBarState.styles;
}

class _AppBarState extends State<AppBar> {
  bool _menuOpen = false;

  void _toggleMenu() {
    setState(() {
      _menuOpen = !_menuOpen;
    });
  }

  void _closeMenu() {
    if (_menuOpen) {
      setState(() {
        _menuOpen = false;
      });
    }
  }

  void _openLink(String uri) {
    _closeMenu();
    web.window.open(uri, '_blank');
  }

  @override
  Component build(BuildContext context) {
    return div(classes: 'app-bar', [
      // Dismiss overlay – closes the menu when clicking outside.
      if (_menuOpen)
        div(
          classes: 'app-bar-dismiss-overlay',
          events: {'click': (_) => _closeMenu()},
          [],
        ),
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
        _buildOverflowMenu(),
      ]),
    ]);
  }

  Component _buildOverflowMenu() {
    return div(classes: 'app-bar-menu-anchor', [
      dp.IconButton(
        icon: 'more_vert',
        tooltip: 'More options',
        label: 'More options',
        onClick: (_) => _toggleMenu(),
      ),
      if (_menuOpen)
        div(classes: 'app-bar-dropdown', [
          button(
            classes: 'app-bar-menu-item',
            onClick: () => _openLink('https://flutter.dev/get-started'),
            [
              const span([.text('Install SDK')]),
              const Icon('launch', size: 16),
            ],
          ),
          button(
            classes: 'app-bar-menu-item',
            onClick: () => _openLink(
              'https://github.com/dart-lang/dart-pad/wiki/Sharing-Guide',
            ),
            [
              const span([.text('Sharing guide')]),
              const Icon('launch', size: 16),
            ],
          ),
        ]),
    ]);
  }

  // ---------------------------------------------------------------------------
  // Styles
  // ---------------------------------------------------------------------------

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
    css('.app-bar-dismiss-overlay').styles(
      position: const .fixed(top: .zero, left: .zero),
      zIndex: const ZIndex(98),
      width: 100.vw,
      height: 100.vh,
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

    // -- Overflow menu --
    css('.app-bar-menu-anchor').styles(
      position: const .relative(),
    ),
    css('.app-bar-dropdown').styles(
      position: .absolute(top: 100.percent),
      zIndex: const ZIndex(99),
      minWidth: 180.px,
      padding: .symmetric(vertical: 4.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(8.px),
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: 4.px,
        blur: 12.px,
        color: const .rgba(0, 0, 0, 0.15),
      ),
      backgroundColor: colorContainer,
      raw: {'right': '0'},
    ),
    css('.app-bar-menu-item').styles(
      display: .flex,
      width: 100.percent,
      padding: .symmetric(horizontal: 12.px, vertical: 8.px),
      border: .none,
      cursor: .pointer,
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(8.px),
      color: colorOnContainer,
      textAlign: .left,
      fontSize: 13.px,
      backgroundColor: Colors.transparent,
    ),
    css('.app-bar-menu-item:hover').styles(
      backgroundColor: colorBorder,
    ),
  ];
}
