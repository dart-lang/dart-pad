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

  static bool matchesShortcut(ShortcutDefinition shortcut, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return true;
    }
    if (shortcut.label.toLowerCase().contains(trimmed)) {
      return true;
    }
    if (shortcut.category?.label.toLowerCase().contains(trimmed) ?? false) {
      return true;
    }
    for (final key in shortcut.resolvedDisplayKeys) {
      if (key.toLowerCase().contains(trimmed)) {
        return true;
      }
    }
    for (final key in shortcut.displayKeys) {
      if (key.toLowerCase().contains(trimmed)) {
        return true;
      }
    }
    final tokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.length > 1) {
      final combined =
          '${shortcut.label} ${shortcut.category?.label ?? ''} ${shortcut.resolvedDisplayKey} ${shortcut.displayKey}'
              .toLowerCase();
      if (tokens.every(combined.contains)) {
        return true;
      }
    }
    return false;
  }
}

class _ShortcutsDialogState extends State<ShortcutsDialog> {
  String _query = '';
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
      final searchInput = web.document.querySelector('.shortcuts-dialog-search-input') as web.HTMLInputElement?;
      if (searchInput != null) {
        searchInput.focus();
      } else {
        final closeButton =
            web.document.querySelector(
                  '.shortcuts-dialog-backdrop [aria-label="Close shortcuts dialog"]',
                )
                as web.HTMLElement?;
        closeButton?.focus();
      }
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
    } else if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() == 'f') {
      event.preventDefault();
      final input = web.document.querySelector('.shortcuts-dialog-search-input') as web.HTMLInputElement?;
      input?.focus();
      input?.select();
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
    final categories = <ShortcutCategory, List<ShortcutDefinition>>{};
    for (final shortcut in shortcutDefinitions) {
      if (shortcut.category case final category?) {
        categories.putIfAbsent(category, () => []).add(shortcut);
      }
    }

    final isSearching = _query.trim().isNotEmpty;
    final shortcutRows = <Component>[];
    for (final MapEntry(key: category, value: shortcuts) in categories.entries) {
      if (isSearching) {
        final matching = shortcuts.where((shortcut) => ShortcutsDialog.matchesShortcut(shortcut, _query)).toList();
        if (matching.isNotEmpty) {
          shortcutRows.add(_categoryHeader(category.label));
          for (final shortcut in matching) {
            shortcutRows.add(_shortcutRow(shortcut));
          }
        }
      } else {
        final primary = shortcuts.where((shortcut) => shortcut.isPrimary).toList();
        final extended = shortcuts.where((shortcut) => !shortcut.isPrimary).toList();

        if (primary.isNotEmpty || (_showMoreShortcuts && extended.isNotEmpty)) {
          shortcutRows.add(_categoryHeader(category.label));
        }
        for (final shortcut in primary) {
          shortcutRows.add(_shortcutRow(shortcut));
        }
        if (_showMoreShortcuts) {
          for (final shortcut in extended) {
            shortcutRows.add(_shortcutRow(shortcut));
          }
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
          div(classes: 'shortcuts-dialog-search', [
            const Icon('search', size: 16, classes: 'shortcuts-dialog-search-icon'),
            input(
              classes: 'shortcuts-dialog-search-input',
              attributes: {
                'type': 'text',
                'placeholder': 'Search shortcuts...',
                'value': _query,
                'aria-label': 'Search shortcuts',
                'spellcheck': 'false',
                'autocomplete': 'off',
              },
              events: {
                'input': (event) {
                  final target = event.target as web.HTMLInputElement;
                  setState(() {
                    _query = target.value;
                  });
                },
              },
            ),
            if (isSearching)
              IconButton(
                icon: 'close',
                iconSize: 14.0,
                label: 'Clear search',
                onClick: (_) {
                  setState(() {
                    _query = '';
                  });
                  final input = web.document.querySelector('.shortcuts-dialog-search-input') as web.HTMLInputElement?;
                  input?.focus();
                },
              ),
          ]),
          div(classes: 'shortcuts-dialog-list', [
            if (isSearching && shortcutRows.isEmpty)
              const div(classes: 'shortcuts-dialog-empty', [
                .text('No matching shortcuts found'),
              ])
            else ...[
              ...shortcutRows,
              if (!isSearching)
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
            ],
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

  Component _shortcutRow(ShortcutDefinition shortcut) {
    final keys = shortcut.resolvedDisplayKeys;
    return div(classes: 'shortcuts-dialog-row', [
      span(classes: 'shortcuts-dialog-command', [.text(shortcut.label)]),
      span(classes: 'shortcuts-dialog-keys', [
        for (var i = 0; i < keys.length; i++)
          if (i == 0)
            span(classes: 'shortcuts-dialog-key', [.text(keys[i])])
          else
            span(classes: 'shortcuts-dialog-alternative', [
              const span(classes: 'shortcuts-dialog-separator', [Component.text('or')]),
              span(classes: 'shortcuts-dialog-key', [.text(keys[i])]),
            ]),
      ]),
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
      width: 440.px,
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
    css('.shortcuts-dialog-search').styles(
      display: .flex,
      padding: .symmetric(vertical: 6.px, horizontal: 12.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .center,
      gap: Gap.all(8.px),
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.shortcuts-dialog-search-icon').styles(
      flex: const .shrink(0),
      color: colorOnSurface.highlight(colorSurface, 0.4),
    ),
    css('.shortcuts-dialog-search-input').styles(
      padding: .symmetric(vertical: 4.px),
      border: .unset,
      outline: .unset,
      flex: const .grow(1),
      color: colorOnSurface,
      fontFamily: defaultFontFamily,
      fontSize: 13.px,
      backgroundColor: const Color('transparent'),
    ),
    css('.shortcuts-dialog-search-input::placeholder').styles(
      color: colorOnSurface.highlight(colorSurface, 0.4),
    ),
    css('.shortcuts-dialog-empty').styles(
      padding: .symmetric(vertical: 24.px, horizontal: 16.px),
      color: colorOnSurface.highlight(colorSurface, 0.4),
      textAlign: .center,
      fontSize: 13.px,
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
    css('.shortcuts-dialog-keys').styles(
      display: .flex,
      flexWrap: .wrap,
      justifyContent: .end,
      alignItems: .center,
      gap: Gap.all(6.px),
    ),
    css('.shortcuts-dialog-alternative').styles(
      display: .inlineFlex,
      alignItems: .center,
      gap: Gap.all(6.px),
    ),
    css('.shortcuts-dialog-separator').styles(
      color: colorOnSurface.highlight(colorSurface, 0.25),
      fontSize: 11.px,
    ),
    css('.shortcuts-dialog-key').styles(
      padding: .symmetric(vertical: 2.px, horizontal: 6.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(4.px),
      color: colorOnContainer,
      fontFamily: monospaceFontFamily,
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
