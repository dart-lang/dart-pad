// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../icons.dart';

/// A single item in a [DropdownMenu].
class DropdownMenuItem {
  const DropdownMenuItem({
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.trailingIconSize = 16,
  });

  /// The text label displayed for this menu item.
  final String label;

  /// Called when the item is tapped.
  final VoidCallback onPressed;

  /// Optional trailing icon name (Material Symbol).
  final String? trailingIcon;

  /// Size of the trailing icon.
  final double trailingIconSize;
}

/// A reusable dropdown menu component.
///
/// Renders a trigger widget that toggles a dropdown panel with a list of
/// [DropdownMenuItem]s. Clicking outside the menu dismisses it.
class DropdownMenu extends StatefulComponent {
  const DropdownMenu({
    required this.items,
    this.trigger,
    super.key,
  });

  /// The menu items to display when the dropdown is open.
  final List<DropdownMenuItem> items;

  /// An optional trigger component. If `null`, a default "more_vert" icon
  /// button is rendered.
  final Component? trigger;

  @override
  State<DropdownMenu> createState() => _DropdownMenuState();

  @css
  static List<StyleRule> get styles => _DropdownMenuState.styles;
}

class _DropdownMenuState extends State<DropdownMenu> {
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

  @override
  Component build(BuildContext context) {
    return div(classes: 'dropdown-menu-anchor', [
      // Dismiss overlay – closes the menu when clicking outside.
      if (_menuOpen)
        div(
          classes: 'dropdown-menu-dismiss-overlay',
          events: {'click': (_) => _closeMenu()},
          [],
        ),
      // Trigger button.
      div(
        events: {'click': (_) => _toggleMenu()},
        [
          component.trigger ??
              const button(
                classes: 'dropdown-menu-default-trigger',
                attributes: {'aria-label': 'More options'},
                [Icon('more_vert', size: 18)],
              ),
        ],
      ),
      // Dropdown panel.
      if (_menuOpen)
        div(classes: 'dropdown-menu-panel', [
          for (final item in component.items)
            button(
              classes: 'dropdown-menu-item',
              onClick: () {
                _closeMenu();
                item.onPressed();
              },
              [
                span([.text(item.label)]),
                if (item.trailingIcon != null) Icon(item.trailingIcon!, size: item.trailingIconSize),
              ],
            ),
        ]),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.dropdown-menu-anchor').styles(
      position: const .relative(),
    ),
    css('.dropdown-menu-dismiss-overlay').styles(
      position: const .fixed(top: .zero, left: .zero),
      zIndex: const ZIndex(98),
      width: 100.vw,
      height: 100.vh,
    ),
    css('.dropdown-menu-panel').styles(
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
    css('.dropdown-menu-item').styles(
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
    css('.dropdown-menu-item:hover').styles(
      backgroundColor: colorBorder,
    ),
  ];
}
