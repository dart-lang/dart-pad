// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import 'shortcut_definitions.dart';

/// Base entry for items inside a [ContextMenu].
sealed class ContextMenuEntry {
  const ContextMenuEntry();
}

/// A non-interactive separator line.
class ContextMenuDivider extends ContextMenuEntry {
  const ContextMenuDivider();
}

/// An interactive item in a [ContextMenu].
class ContextMenuItem extends ContextMenuEntry {
  const ContextMenuItem({
    required this.label,
    required this.onPressed,
    this.shortcut,
    this.disabled = false,
    this.destructive = false,
  });

  /// Creates a context menu item from a [ShortcutDefinition].
  ///
  /// The [shortcut] definition provides the default [label] and [shortcut] string
  /// (resolved via [resolveDisplayKey]).
  factory ContextMenuItem.fromShortcut({
    required ShortcutDefinition shortcut,
    required VoidCallback onPressed,
  }) => ContextMenuItem(
    label: shortcut.label,
    onPressed: onPressed,
    shortcut: resolveDisplayKey(shortcut.displayKey),
  );

  /// The text label displayed for this menu item.
  final String label;

  /// Called when the item is activated.
  final VoidCallback onPressed;

  /// Optional keyboard shortcut label (e.g. "Ctrl+.", "F2", "Shift+Alt+F").
  final String? shortcut;

  /// Whether the item is disabled and non-clickable.
  final bool disabled;

  /// Whether this is a destructive action (rendered with error styling).
  final bool destructive;
}

/// Controller that manages displaying and dismissing a floating context menu.
class ContextMenuController extends ChangeNotifier {
  bool _isDisposed = false;
  bool _isOpen = false;
  double _x = 0;
  double _y = 0;
  List<ContextMenuEntry> _items = const [];

  bool get isOpen => _isOpen;
  double get x => _x;
  double get y => _y;
  List<ContextMenuEntry> get items => _items;

  /// Opens the context menu at viewport coordinates ([x], [y]) with [items].
  void show(double x, double y, List<ContextMenuEntry> items) {
    if (_isDisposed) {
      return;
    }
    if (items.isEmpty) {
      hide();
      return;
    }
    _x = x;
    _y = y;
    _items = items;
    _isOpen = true;
    notifyListeners();
  }

  /// Closes the currently active context menu.
  void hide() {
    if (_isDisposed) {
      return;
    }
    if (!_isOpen) {
      return;
    }
    _isOpen = false;
    _items = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}

/// A floating context menu rendered at a given (x, y) coordinate.
class ContextMenu extends StatefulComponent {
  const ContextMenu({
    required this.x,
    required this.y,
    required this.items,
    required this.onClose,
    this.isOpen = true,
    super.key,
  });

  final double x;
  final double y;
  final List<ContextMenuEntry> items;
  final VoidCallback onClose;

  /// Whether the menu is visible and responds to global interactions.
  ///
  /// Keeping the component mounted while hidden avoids replacing a component
  /// subtree during a document-level event callback.
  final bool isOpen;

  @override
  State<ContextMenu> createState() => _ContextMenuState();

  @css
  static List<StyleRule> get styles => _ContextMenuState.styles;
}

class _ContextMenuState extends State<ContextMenu> {
  final GlobalNodeKey _menuKey = GlobalNodeKey();
  StreamSubscription<web.MouseEvent>? _dismissSubscription;
  StreamSubscription<web.KeyboardEvent>? _keySubscription;
  StreamSubscription<web.Event>? _resizeSubscription;
  double? _adjustedX;
  double? _adjustedY;
  bool _isPositioned = false;

  @override
  void initState() {
    super.initState();
    Timer.run(() {
      if (!mounted) {
        return;
      }
      _dismissSubscription = web.EventStreamProviders.mouseDownEvent.forTarget(web.document).listen((event) {
        final menu = _menuKey.currentNode;
        final target = event.target as web.Node?;
        if (component.isOpen && menu != null && target != null && !menu.contains(target)) {
          component.onClose();
        }
      });
      _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_handleGlobalKeyDown);
      _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
        component.onClose();
      });
      if (component.isOpen) {
        _adjustPosition();
        _focusFirstItem();
      }
    });
  }

  @override
  void didUpdateComponent(ContextMenu oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (!component.isOpen) {
      _isPositioned = false;
      return;
    }
    if (oldComponent.x != component.x || oldComponent.y != component.y) {
      _adjustedX = component.x;
      _adjustedY = component.y;
      _isPositioned = false;
    }
    Timer.run(() {
      if (mounted) {
        _adjustPosition();
        if (!oldComponent.isOpen) {
          _focusFirstItem();
        }
      }
    });
  }

  @override
  void dispose() {
    _dismissSubscription?.cancel();
    _dismissSubscription = null;
    _keySubscription?.cancel();
    _keySubscription = null;
    _resizeSubscription?.cancel();
    _resizeSubscription = null;
    super.dispose();
  }

  List<web.HTMLButtonElement> _getEnabledItems() {
    final menu = _menuKey.currentNode as web.HTMLElement?;
    if (menu == null) {
      return const [];
    }
    final nodeList = menu.querySelectorAll('.context-menu-item:not(:disabled)');
    final items = <web.HTMLButtonElement>[];
    for (var i = 0; i < nodeList.length; i++) {
      final node = nodeList.item(i);
      if (node != null) {
        final btn = node as web.HTMLButtonElement;
        if (!btn.disabled) {
          items.add(btn);
        }
      }
    }
    return items;
  }

  int _findFocusedIndex(List<web.HTMLButtonElement> items) {
    final active = web.document.activeElement;
    if (active == null) {
      return -1;
    }
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (identical(item, active) || item.contains(active)) {
        return i;
      }
    }
    return -1;
  }

  void _focusFirstItem() {
    final items = _getEnabledItems();
    if (items.isNotEmpty) {
      items.first.focus();
    }
  }

  void _adjustPosition() {
    final menu = _menuKey.currentNode as web.HTMLElement?;
    if (menu == null) {
      return;
    }

    final rect = menu.getBoundingClientRect();
    final vpW = web.window.innerWidth;
    final vpH = web.window.innerHeight;

    double x = component.x;
    double y = component.y;

    final maxW = vpW.toDouble();
    final maxH = vpH.toDouble();

    const margin = 8.0;
    if (maxW > margin && x + rect.width > maxW - margin) {
      x = (maxW - rect.width - margin).clamp(margin, maxW);
    }
    if (maxH > margin && y + rect.height > maxH - margin) {
      y = (maxH - rect.height - margin).clamp(margin, maxH);
    }

    _adjustedX = x;
    _adjustedY = y;
    _isPositioned = true;

    menu.style.left = '${x}px';
    menu.style.top = '${y}px';
    menu.style.opacity = '1';
  }

  void _handleGlobalKeyDown(web.KeyboardEvent event) {
    if (!component.isOpen) {
      return;
    }
    switch (event.key) {
      case 'Escape':
        event.preventDefault();
        event.stopPropagation();
        component.onClose();
      case 'ArrowDown':
        final items = _getEnabledItems();
        if (items.isNotEmpty) {
          event.preventDefault();
          event.stopPropagation();
          final index = _findFocusedIndex(items);
          if (index == -1 || index >= items.length - 1) {
            items.first.focus();
          } else {
            items[index + 1].focus();
          }
        }
      case 'ArrowUp':
        final items = _getEnabledItems();
        if (items.isNotEmpty) {
          event.preventDefault();
          event.stopPropagation();
          final index = _findFocusedIndex(items);
          if (index == -1 || index <= 0) {
            items.last.focus();
          } else {
            items[index - 1].focus();
          }
        }
      case 'Home':
        final items = _getEnabledItems();
        if (items.isNotEmpty) {
          event.preventDefault();
          event.stopPropagation();
          items.first.focus();
        }
      case 'End':
        final items = _getEnabledItems();
        if (items.isNotEmpty) {
          event.preventDefault();
          event.stopPropagation();
          items.last.focus();
        }
      case 'Enter':
      case ' ':
      case 'Spacebar':
        final items = _getEnabledItems();
        final index = _findFocusedIndex(items);
        if (index != -1) {
          event.preventDefault();
          event.stopPropagation();
          items[index].click();
        }
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      key: _menuKey,
      classes: 'context-menu',
      attributes: const {
        'role': 'menu',
        'tabindex': '-1',
      },
      styles: Styles(
        raw: {
          'opacity': _isPositioned ? '1' : '0',
          'left': '${_adjustedX ?? component.x}px',
          'top': '${_adjustedY ?? component.y}px',
          'display': component.isOpen ? 'flex' : 'none',
        },
      ),
      [
        for (final entry in component.items)
          switch (entry) {
            ContextMenuDivider() => const div(classes: 'context-menu-divider', []),
            ContextMenuItem() => button(
              classes: [
                'context-menu-item',
                if (entry.destructive) 'destructive',
              ].join(' '),
              attributes: {
                'type': 'button',
                'role': 'menuitem',
                if (entry.disabled) 'disabled': '',
                if (entry.disabled) 'aria-disabled': 'true',
              },
              onClick: entry.disabled
                  ? null
                  : () {
                      try {
                        entry.onPressed();
                      } finally {
                        Timer.run(component.onClose);
                      }
                    },
              [
                span(classes: 'context-menu-item-label', [.text(entry.label)]),
                if (entry.shortcut != null) span(classes: 'context-menu-item-shortcut', [.text(entry.shortcut!)]),
              ],
            ),
          },
      ],
    );
  }

  static List<StyleRule> get styles => [
    css('.context-menu').styles(
      display: .flex,
      position: const .fixed(),
      zIndex: const ZIndex(9999),
      minWidth: 200.px,
      maxWidth: 340.px,
      maxHeight: const Unit.expression('min(480px, calc(100vh - 24px))'),
      padding: .symmetric(vertical: 4.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(5.px),
      shadow: BoxShadow(
        offsetX: .zero,
        offsetY: 4.px,
        blur: 16.px,
        color: const .rgba(0, 0, 0, 0.2),
      ),
      flexDirection: .column,
      color: colorOnContainer,
      fontFamily: const .list([FontFamily('Inter'), FontFamily('Segoe UI'), FontFamilies.sansSerif]),
      fontSize: 12.px,
      backgroundColor: colorContainer,
      raw: {
        'overflow-y': 'auto',
      },
    ),
    css('.context-menu-divider').styles(
      height: 1.px,
      margin: .symmetric(vertical: 3.px),
      backgroundColor: colorBorder,
    ),
    css('.context-menu-item', [
      css('&').styles(
        display: .flex,
        width: 100.percent,
        padding: .symmetric(vertical: 5.px, horizontal: 14.px),
        border: .none,
        outline: const Outline(style: .none),
        cursor: .pointer,
        transition: Transition('background-color', duration: 80.ms),
        alignItems: .center,
        gap: Gap.all(12.px),
        color: colorOnContainer,
        textAlign: .left,
        fontSize: 12.px,
        backgroundColor: Colors.transparent,
      ),
      css('&:hover:not(:disabled), &:focus-visible:not(:disabled)').styles(
        color: colorOnContainer,
        backgroundColor: colorContainer.highlight(colorOnSurface, 0.1),
      ),
      css('&:disabled').styles(
        opacity: 0.45,
        cursor: .defaultCursor,
      ),
      css('&.destructive').styles(
        color: colorError,
      ),
      css('&.destructive:hover:not(:disabled), &.destructive:focus-visible:not(:disabled)').styles(
        color: colorError,
        backgroundColor: colorErrorSurface,
      ),
    ]),
    css('.context-menu-item-label').styles(
      overflow: .hidden,
      flex: const Flex(grow: 1, basis: .zero),
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.context-menu-item-shortcut').styles(
      padding: .only(left: 16.px),
      opacity: 0.6,
      flex: const .shrink(0),
      color: colorOnContainer,
      fontFamily: const .list([FontFamily('Inter'), FontFamily('Segoe UI'), FontFamilies.sansSerif]),
      fontSize: 11.px,
      whiteSpace: .noWrap,
    ),
  ];
}
