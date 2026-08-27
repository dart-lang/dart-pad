// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../icons.dart';
import 'icon_button.dart';
import 'shortcut_definitions.dart';

/// Selector for all focusable elements inside the dialog.
const _focusableSelector = 'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';

/// A modal dialog that displays available keyboard shortcuts organized by category.
class ShortcutsDialog extends StatefulComponent {
  const ShortcutsDialog({required this.onClose, super.key});

  /// Called when the dialog is dismissed.
  final VoidCallback onClose;

  @override
  State<ShortcutsDialog> createState() => _ShortcutsDialogState();

  @css
  static List<StyleRule> get styles => _ShortcutsDialogState.styles;
}

class _ShortcutsDialogState extends State<ShortcutsDialog> {
  bool _showMoreShortcuts = false;
  StreamSubscription<web.KeyboardEvent>? _keySubscription;

  @override
  void initState() {
    super.initState();
    _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_handleKeyDown);
    Timer.run(() {
      if (!mounted) {
        return;
      }
      final closeButton =
          web.document.querySelector(
                '.shortcuts-dialog-backdrop [aria-label="Close shortcuts dialog"]',
              )
              as web.HTMLElement?;
      closeButton?.focus();
    });
  }

  @override
  void dispose() {
    _keySubscription?.cancel();
    _keySubscription = null;
    super.dispose();
  }

  void _handleKeyDown(web.KeyboardEvent event) {
    if (event.defaultPrevented) {
      return;
    }
    if (event.key == 'Escape') {
      event.preventDefault();
      component.onClose();
    } else if (event.key == 'Tab') {
      _trapFocus(event);
    }
  }

  /// Prevents Tab / Shift+Tab from moving focus outside the dialog.
  void _trapFocus(web.KeyboardEvent event) {
    final backdrop = web.document.querySelector('.shortcuts-dialog-backdrop');
    if (backdrop == null) {
      return;
    }
    final focusable = backdrop.querySelectorAll(_focusableSelector);
    if (focusable.length == 0) {
      return;
    }
    final first = focusable.item(0) as web.HTMLElement?;
    final last = focusable.item(focusable.length - 1) as web.HTMLElement?;
    if (first == null || last == null) {
      return;
    }
    final active = web.document.activeElement;
    if (event.shiftKey) {
      if (active == first) {
        event.preventDefault();
        last.focus();
      }
    } else {
      if (active == last) {
        event.preventDefault();
        first.focus();
      }
    }
  }

  @override
  Component build(BuildContext context) {
    // Group shortcuts by category, preserving the order of first appearance.
    final categories = <ShortcutCategory, List<ShortcutDefinition>>{};
    for (final shortcut in shortcutDefinitions) {
      if (shortcut.category case final category?) {
        categories.putIfAbsent(category, () => []).add(shortcut);
      }
    }

    final shortcutRows = <Component>[];
    for (final MapEntry(key: category, value: shortcuts) in categories.entries) {
      final primary = shortcuts.where((shortcut) => shortcut.isPrimary).toList();
      final extended = shortcuts.where((shortcut) => !shortcut.isPrimary).toList();

      // Only show the category header if it has visible shortcuts.
      if (primary.isNotEmpty || (_showMoreShortcuts && extended.isNotEmpty)) {
        shortcutRows.add(_categoryHeader(category.label));
      }
      for (final shortcut in primary) {
        shortcutRows.add(_shortcutRow(shortcut.label, resolveDisplayKey(shortcut.displayKey)));
      }
      if (_showMoreShortcuts) {
        for (final shortcut in extended) {
          shortcutRows.add(_shortcutRow(shortcut.label, resolveDisplayKey(shortcut.displayKey)));
        }
      }
    }

    return div(
      classes: 'shortcuts-dialog-backdrop',
      events: {
        'click': (event) {
          if (event.target == event.currentTarget) {
            component.onClose();
          }
        },
      },
      attributes: const {
        'role': 'dialog',
        'aria-modal': 'true',
        'aria-labelledby': 'shortcuts-dialog-title',
      },
      [
        div(classes: 'shortcuts-dialog', [
          div(classes: 'shortcuts-dialog-header', [
            const h2(id: 'shortcuts-dialog-title', [
              .text('Keyboard shortcuts'),
            ]),
            IconButton(
              icon: 'close',
              label: 'Close shortcuts dialog',
              onClick: (_) => component.onClose(),
            ),
          ]),
          div(classes: 'shortcuts-dialog-list', [
            ...shortcutRows,
            button(
              classes: 'shortcuts-dialog-toggle-btn',
              events: {
                'click': (_) {
                  setState(() {
                    _showMoreShortcuts = !_showMoreShortcuts;
                  });
                },
              },
              attributes: const {'type': 'button'},
              [
                span([
                  .text(_showMoreShortcuts ? 'Show fewer shortcuts' : 'Show more shortcuts'),
                ]),
                Icon(_showMoreShortcuts ? 'expand_less' : 'expand_more', size: 16),
              ],
            ),
          ]),
        ]),
      ],
    );
  }

  Component _categoryHeader(String title) {
    return div(classes: 'shortcuts-dialog-category', [
      span([.text(title)]),
    ]);
  }

  Component _shortcutRow(String command, String shortcut) {
    return div(classes: 'shortcuts-dialog-row', [
      span(classes: 'shortcuts-dialog-command', [.text(command)]),
      span(classes: 'shortcuts-dialog-key', [.text(shortcut)]),
    ]);
  }

  static List<StyleRule> get styles => [
    css('.shortcuts-dialog-backdrop').styles(
      display: .flex,
      position: .fixed(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      zIndex: const ZIndex(9999),
      justifyContent: .center,
      alignItems: .center,
      backgroundColor: const Color('rgba(0, 0, 0, 0.55)'),
    ),
    css('.shortcuts-dialog').styles(
      display: .flex,
      minWidth: 340.px,
      maxWidth: 90.percent,
      maxHeight: 85.vh,
      padding: .zero,
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(6.px),
      overflow: .hidden,
      flexDirection: .column,
      color: colorOnSurface,
      backgroundColor: colorSurface,
    ),
    css('.shortcuts-dialog-header').styles(
      display: .flex,
      padding: .symmetric(vertical: 10.px, horizontal: 14.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(10.px),
    ),
    css('.shortcuts-dialog-header h2').styles(
      margin: .zero,
      fontSize: 15.px,
      fontWeight: .w500,
    ),
    css('.shortcuts-dialog-list').styles(
      display: .flex,
      minHeight: 0.px,
      padding: .symmetric(vertical: 8.px, horizontal: 14.px),
      overflow: const .only(y: .auto),
      flexDirection: .column,
      gap: Gap.all(2.px),
      flex: const .grow(1),
    ),
    css('.shortcuts-dialog-category').styles(
      display: .flex,
      padding: .only(top: 10.px, bottom: 4.px),
      margin: .only(top: 6.px),
      border: .only(
        top: .solid(color: colorBorder, width: 1.px),
      ),
      color: colorOnSurface.highlight(colorSurface, 0.25),
      fontSize: 11.px,
      fontWeight: .w600,
      textTransform: .upperCase,
      letterSpacing: 0.5.px,
    ),
    css('.shortcuts-dialog-category:first-child').styles(
      padding: .only(top: 2.px, bottom: 4.px),
      margin: .zero,
      border: .unset,
    ),
    css('.shortcuts-dialog-row').styles(
      display: .flex,
      padding: .symmetric(vertical: 5.px),
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(20.px),
    ),
    css('.shortcuts-dialog-command').styles(
      color: colorOnSurface,
      fontSize: 12.px,
    ),
    css('.shortcuts-dialog-key').styles(
      padding: .symmetric(vertical: 2.px, horizontal: 6.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(4.px),
      color: colorOnContainer,
      fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
      fontSize: 11.px,
      whiteSpace: .noWrap,
      backgroundColor: colorContainer,
    ),
    css('.shortcuts-dialog-toggle-btn').styles(
      display: .flex,
      width: 100.percent,
      padding: .symmetric(vertical: 7.px, horizontal: 8.px),
      margin: .only(top: 8.px, bottom: 4.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(4.px),
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      gap: Gap.all(4.px),
      color: colorOnSurface,
      fontSize: 12.px,
      fontWeight: .w500,
      backgroundColor: colorSurface,
    ),
    css('.shortcuts-dialog-toggle-btn:hover').styles(
      backgroundColor: colorContainer,
    ),
  ];
}
