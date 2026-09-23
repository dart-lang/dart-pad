// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';

const _dropdownFontFamily = FontFamily.list([
  FontFamily('Google Sans Flex'),
  FontFamily('Roboto'),
  FontFamily('ui-sans'),
  FontFamilies.sansSerif,
]);

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
    this.leadingIcon,
    this.leadingIconSize = 18,
    this.trailingIcon,
    this.trailingIconSize = 16,
    this.isSelected = false,
  });

  /// The text label displayed for this menu item.
  final String label;

  /// Called when the item is tapped.
  final VoidCallback onPressed;

  /// Optional leading image URL (e.g. a logo).
  final String? leadingImage;

  /// Optional leading icon name (Material Symbol).
  final String? leadingIcon;

  /// Size of the leading icon.
  final double leadingIconSize;

  /// Optional trailing icon name (Material Symbol).
  final String? trailingIcon;

  /// Size of the trailing icon.
  final double trailingIconSize;

  /// Whether this item represents the currently selected value.
  final bool isSelected;
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
    return div(
      key: _anchorKey,
      classes: 'dropdown dropdown-menu-anchor',
      attributes: {
        'data-expanded': _menuOpen ? 'true' : 'false',
      },
      [
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
        // Dropdown panel (nav.dropdown-menu).
        if (_menuOpen)
          nav(
            classes: [
              'dropdown-menu',
              'dropdown-menu-panel',
              if (component.alignLeft) 'dropdown-menu-panel-left',
              if (component.openUp) 'dropdown-menu-panel-up',
            ].join(' '),
            attributes: const {'role': 'menu'},
            [
              ul([
                for (final entry in component.items)
                  li([
                    switch (entry) {
                      DropdownMenuDivider(:final label) => div(
                        classes: 'dropdown-menu-divider',
                        [
                          span([.text(label)]),
                        ],
                      ),
                      DropdownMenuItem() => button(
                        classes: [
                          'dropdown-menu-item',
                          if (entry.isSelected) 'active',
                        ].join(' '),
                        attributes: const {'role': 'menuitem'},
                        onClick: () {
                          _closeMenu();
                          entry.onPressed();
                        },
                        [
                          if (entry.leadingImage case final leadingImage?)
                            img(
                              src: leadingImage,
                              alt: '',
                              classes: 'dropdown-menu-item-image',
                              attributes: const {'width': '20', 'height': '20'},
                            ),
                          if (entry.leadingIcon case final leadingIcon?) Icon(leadingIcon, size: entry.leadingIconSize),
                          span(classes: 'dropdown-menu-item-name', [.text(entry.label)]),
                          if (entry.trailingIcon case final trailingIcon?)
                            Icon(trailingIcon, size: entry.trailingIconSize),
                        ],
                      ),
                    },
                  ]),
              ]),
            ],
          ),
      ],
    );
  }

  static List<StyleRule> get styles => [
    css('.dropdown-menu-anchor').styles(
      display: .inlineFlex,
      position: const .relative(),
    ),
    // Dropdown container (nav.dropdown-menu)
    css('.dropdown-menu').styles(
      position: .absolute(top: 100.percent),
      zIndex: const ZIndex(200),
      minWidth: 120.px,
      padding: .all(3.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(9.px),
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: 6.px,
        blur: 18.px,
        color: const .rgba(0, 0, 0, 0.15),
      ),
      color: colorOnContainer,
      fontFamily: _dropdownFontFamily,
      backgroundColor: colorContainer,
      raw: {
        'width': 'max-content',
        'right': '0',
        'font-optical-sizing': 'auto',
        '-webkit-font-smoothing': 'antialiased',
        '-moz-osx-font-smoothing': 'grayscale',
      },
    ),
    css('.dropdown-menu-panel-left').styles(
      raw: {'left': '0', 'right': 'auto'},
    ),
    css('.dropdown-menu-panel-up').styles(
      position: .absolute(bottom: 100.percent),
      raw: {'top': 'auto', 'margin-bottom': '4px'},
    ),
    // Dark mode for dropdown menu panel matching dart.dev chrome
    css('html[data-theme="dark"] .dropdown-menu').styles(
      border: .all(color: const Color('#394c60'), width: 1.px),
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: 6.px,
        blur: 18.px,
        color: const .rgba(0, 0, 0, 0.35),
      ),
      color: const Color('#f3f4f6'),
      backgroundColor: const Color('#1c2834'),
    ),
    // List styling
    css('.dropdown-menu ul').styles(
      display: .flex,
      padding: .zero,
      margin: .zero,
      flexDirection: .column,
      raw: {'list-style': 'none'},
    ),
    css('.dropdown-menu li').styles(
      padding: .all(2.px),
      margin: .zero,
      raw: {'list-style': 'none'},
    ),
    // Divider
    css('.dropdown-menu-divider').styles(
      padding: .only(left: 10.px, right: 10.px, top: 8.px, bottom: 4.px),
      color: colorOnContainer,
      fontSize: 12.px,
      fontWeight: .w700,
      raw: {
        'text-transform': 'uppercase',
        'letter-spacing': '0.05em',
      },
    ),
    css('html[data-theme="dark"] .dropdown-menu-divider').styles(
      color: const Color('#a8acad'),
    ),
    // Items
    css('.dropdown-menu-item').styles(
      display: .flex,
      width: 100.percent,
      padding: .symmetric(horizontal: 10.px, vertical: 6.px),
      border: .none,
      radius: .circular(7.px),
      cursor: .pointer,
      flexDirection: .row,
      justifyContent: .start,
      alignItems: .center,
      gap: Gap.all(8.px),
      color: .inherit,
      textAlign: .left,
      fontFamily: .inherit,
      fontSize: 14.px,
      textDecoration: const TextDecoration(line: .none),
      whiteSpace: .noWrap,
      backgroundColor: Colors.transparent,
      raw: {
        'user-select': 'none',
        'box-sizing': 'border-box',
      },
    ),
    css('.dropdown-menu-item:hover').styles(
      backgroundColor: const Color.rgba(0, 0, 0, 0.05),
    ),
    css('html[data-theme="dark"] .dropdown-menu-item:hover').styles(
      backgroundColor: const Color.rgba(255, 255, 255, 0.05),
    ),
    // Active / Selected state
    css('.dropdown-menu-item.active').styles(
      fontWeight: .w500,
      backgroundColor: const Color.rgba(25, 103, 210, 0.08),
    ),
    css('html[data-theme="dark"] .dropdown-menu-item.active').styles(
      backgroundColor: const Color.rgba(25, 103, 210, 0.18),
    ),
    css('.dropdown-menu-item.active:hover').styles(
      backgroundColor: const Color.rgba(25, 103, 210, 0.12),
    ),
    css('html[data-theme="dark"] .dropdown-menu-item.active:hover').styles(
      backgroundColor: const Color.rgba(25, 103, 210, 0.24),
    ),
    // Leading image
    css('.dropdown-menu-item-image').styles(
      width: 20.px,
      height: 20.px,
      flex: const .shrink(0),
    ),
    // Item name
    css('.dropdown-menu-item-name').styles(
      flex: const .grow(1),
    ),
  ];
}
