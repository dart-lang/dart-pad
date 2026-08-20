// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';

/// Base type for entries in a [DropdownMenu].
sealed class DropdownMenuEntry {
  const DropdownMenuEntry();
}

/// A non-interactive text divider / category header in a [DropdownMenu].
class DropdownMenuDivider extends DropdownMenuEntry {
  const DropdownMenuDivider({required this.label});

  /// The category label displayed as a header.
  final String label;
}

/// A single interactive item in a [DropdownMenu].
class DropdownMenuItem extends DropdownMenuEntry {
  const DropdownMenuItem({
    required this.label,
    required this.onPressed,
    this.leadingImage,
    this.trailingIcon,
    this.trailingIconSize = 16,
  });

  /// The text label displayed for this menu item.
  final String label;

  /// Called when the item is tapped.
  final VoidCallback onPressed;

  /// Optional leading image URL (e.g. a logo).
  final String? leadingImage;

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
    this.alignLeft = false,
    this.openUp = false,
    this.disabled = false,
    super.key,
  });

  /// The menu entries to display when the dropdown is open.
  final List<DropdownMenuEntry> items;

  /// An optional trigger component. If `null`, a default "more_vert" icon
  /// button is rendered.
  final Component? trigger;

  /// When `true`, the dropdown panel aligns to the left edge of the anchor
  /// instead of the right edge.
  final bool alignLeft;

  /// When `true`, the dropdown panel opens upwards above the anchor.
  final bool openUp;

  /// When `true`, the trigger is not interactive and the menu cannot be opened.
  final bool disabled;

  @override
  State<DropdownMenu> createState() => _DropdownMenuState();

  @css
  static List<StyleRule> get styles => _DropdownMenuState.styles;
}

class _DropdownMenuState extends State<DropdownMenu> {
  bool _menuOpen = false;
  StreamSubscription<web.MouseEvent>? _dismissSubscription;
  final _anchorKey = GlobalNodeKey();

  void _toggleMenu() {
    if (component.disabled) {
      return;
    }
    if (_menuOpen) {
      _closeMenu();
    } else {
      _openMenu();
    }
  }

  void _openMenu() {
    setState(() {
      _menuOpen = true;
    });
    // Defer so the current click event doesn't immediately trigger dismissal.
    Timer.run(() {
      if (!mounted || !_menuOpen) {
        return;
      }
      _dismissSubscription = web.EventStreamProviders.mouseDownEvent.forTarget(web.document).listen((event) {
        final anchor = _anchorKey.currentNode;
        final target = event.target as web.Node?;
        if (anchor != null && target != null && !anchor.contains(target)) {
          _closeMenu();
        }
      });
    });
  }

  void _closeMenu() {
    if (_menuOpen) {
      _dismissSubscription?.cancel();
      _dismissSubscription = null;
      setState(() {
        _menuOpen = false;
      });
    }
  }

  @override
  void dispose() {
    _dismissSubscription?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return div(key: _anchorKey, classes: 'dropdown-menu-anchor', [
      // Trigger button.
      Component.apply(
        events: {'click': (_) => _toggleMenu()},
        child:
            component.trigger ??
            const button(
              classes: 'dropdown-menu-default-trigger',
              attributes: {'aria-label': 'More options'},
              [Icon('more_vert', size: 18)],
            ),
      ),
      // Dropdown panel.
      if (_menuOpen)
        div(
          classes: [
            'dropdown-menu-panel',
            if (component.alignLeft) 'dropdown-menu-panel-left',
            if (component.openUp) 'dropdown-menu-panel-up',
          ].join(' '),
          [
            for (final entry in component.items)
              switch (entry) {
                DropdownMenuDivider(:final label) => div(
                  classes: 'dropdown-menu-divider',
                  [
                    span([.text(label)]),
                  ],
                ),
                DropdownMenuItem() => button(
                  classes: 'dropdown-menu-item',
                  onClick: () {
                    _closeMenu();
                    entry.onPressed();
                  },
                  [
                    if (entry.leadingImage != null)
                      img(
                        src: entry.leadingImage!,
                        alt: '',
                        classes: 'dropdown-menu-item-image',
                      ),
                    span([.text(entry.label)]),
                    if (entry.trailingIcon != null) Icon(entry.trailingIcon!, size: entry.trailingIconSize),
                  ],
                ),
              },
          ],
        ),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.dropdown-menu-anchor').styles(
      position: const .relative(),
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
    css('.dropdown-menu-panel-left').styles(
      raw: {'left': '0', 'right': 'auto'},
    ),
    css('.dropdown-menu-panel-up').styles(
      position: .absolute(bottom: 100.percent),
      raw: {'top': 'auto', 'margin-bottom': '4px'},
    ),
    css('.dropdown-menu-divider').styles(
      padding: .only(left: 12.px, right: 12.px, top: 12.px, bottom: 4.px),
      color: colorOnContainer,
      fontSize: 14.px,
      fontWeight: .w700,
    ),
    css('.dropdown-menu-divider:first-child').styles(
      padding: .only(left: 12.px, right: 12.px, top: 6.px, bottom: 4.px),
    ),
    css('.dropdown-menu-item').styles(
      display: .flex,
      width: 100.percent,
      padding: .symmetric(horizontal: 12.px, vertical: 8.px),
      border: .none,
      cursor: .pointer,
      alignItems: .center,
      gap: Gap.all(6.px),
      color: colorOnContainer,
      textAlign: .left,
      fontSize: 14.px,
      backgroundColor: Colors.transparent,
    ),
    css('.dropdown-menu-item:hover').styles(
      backgroundColor: colorBorder,
    ),
    css('.dropdown-menu-item-image').styles(
      width: 20.px,
      height: 20.px,
    ),
  ];
}
