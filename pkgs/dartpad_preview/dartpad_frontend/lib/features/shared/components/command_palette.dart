// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/dom.dart' hide label;
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../workspace/workspace_session.dart';
import 'command_palette_actions.dart';

export 'command_palette_actions.dart';

/// A modal dialog for searching and executing application commands.
///
/// Displays all available actions immediately when opened, and dynamically
/// filters them as the user types. Supports arrow navigation, Enter selection,
/// and Escape / backdrop dismissal.
final class CommandPalette extends StatefulComponent {
  /// Creates a [CommandPalette] with the given [actions] and execution [context].
  const CommandPalette({
    this.context = const CommandContext(),
    this.actions = allCommandActions,
    required this.onClose,
    super.key,
  });

  /// Creates a [CommandPalette] populated with default workspace actions from [session].
  factory CommandPalette.fromSession({
    required WorkspaceSession session,
    String projectDir = '',
    List<CommandPaletteAction> actions = allCommandActions,
    required VoidCallback onClose,
    Key? key,
  }) => CommandPalette(
    key: key,
    context: CommandContext(
      session: session,
      projectDir: projectDir,
    ),
    actions: actions,
    onClose: onClose,
  );

  /// The execution context passed to triggered command actions.
  final CommandContext context;

  /// The list of actions available in the command palette.
  final List<CommandPaletteAction> actions;

  /// Called when the command palette is dismissed.
  final VoidCallback onClose;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();

  @css
  static List<StyleRule> get styles => _CommandPaletteState.styles;

  /// Checks whether [action] matches [query] against label, description, category, shortcut, or aliases.
  static bool matchesCommand(CommandPaletteAction action, String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      return true;
    }
    if (action.label.toLowerCase().contains(trimmed)) {
      return true;
    }
    if (action.description.toLowerCase().contains(trimmed)) {
      return true;
    }
    if (action.category?.label.toLowerCase().contains(trimmed) ?? false) {
      return true;
    }
    for (final alias in action.aliases) {
      if (alias.toLowerCase().contains(trimmed)) {
        return true;
      }
    }
    final currentShortcut = action.shortcut;
    if (currentShortcut != null) {
      if (currentShortcut.displayKey.toLowerCase().contains(trimmed) ||
          action.resolvedDisplayKey.toLowerCase().contains(trimmed)) {
        return true;
      }
    }
    // Also match individual words in query
    final tokens = trimmed.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    if (tokens.length > 1) {
      final combined =
          '${action.label} ${action.description} ${action.category?.label ?? ''} ${action.resolvedDisplayKey} ${action.aliases.join(' ')}'
              .toLowerCase();
      if (tokens.every(combined.contains)) {
        return true;
      }
    }
    return false;
  }
}

class _CommandPaletteState extends State<CommandPalette> {
  String _query = '';
  int _selectedIndex = 0;
  StreamSubscription<web.KeyboardEvent>? _keySubscription;

  @override
  void initState() {
    super.initState();
    _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_handleKeyDown);
    Timer.run(() {
      if (!mounted) {
        return;
      }
      final input = web.document.querySelector('.command-palette-input') as web.HTMLInputElement?;
      input?.focus();
    });
  }

  @override
  void dispose() {
    _keySubscription?.cancel();
    _keySubscription = null;
    super.dispose();
  }

  List<CommandPaletteAction> get _filteredActions {
    return component.actions.where((action) {
      if (action.isEnabled != null && !action.isEnabled!(component.context)) {
        return false;
      }
      return CommandPalette.matchesCommand(action, _query);
    }).toList();
  }

  int _effectiveIndex(int length) => length == 0 ? 0 : _selectedIndex.clamp(0, length - 1);

  void _handleKeyDown(web.KeyboardEvent event) {
    if (event.defaultPrevented) {
      return;
    }
    if (event.key == 'Escape') {
      event.preventDefault();
      component.onClose();
      return;
    }

    final filtered = _filteredActions;
    final effectiveIndex = _effectiveIndex(filtered.length);
    if (event.key == 'ArrowDown') {
      event.preventDefault();
      if (filtered.isNotEmpty) {
        setState(() {
          _selectedIndex = (effectiveIndex + 1) % filtered.length;
        });
        _scrollToSelected();
      }
      return;
    } else if (event.key == 'ArrowUp') {
      event.preventDefault();
      if (filtered.isNotEmpty) {
        setState(() {
          _selectedIndex = (effectiveIndex - 1 + filtered.length) % filtered.length;
        });
        _scrollToSelected();
      }
      return;
    } else if (event.key == 'Enter') {
      event.preventDefault();
      if (filtered.isNotEmpty) {
        _executeAction(filtered[effectiveIndex]);
      }
      return;
    } else if (event.key == 'Tab') {
      // Prevent focus from leaving the command palette
      event.preventDefault();
    }
  }

  void _scrollToSelected() {
    Timer.run(() {
      final activeElem = web.document.querySelector('.command-palette-item.active') as web.HTMLElement?;
      activeElem?.scrollIntoView();
    });
  }

  void _executeAction(CommandPaletteAction action) {
    component.onClose();
    unawaited(Future.microtask(() => action.onExecute(component.context)));
  }

  @override
  Component build(BuildContext context) {
    final filtered = _filteredActions;
    final selectedIndex = _effectiveIndex(filtered.length);

    return div(
      classes: 'command-palette-backdrop',
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
        'aria-label': 'Command Palette',
      },
      [
        div(classes: 'command-palette', [
          div(classes: 'command-palette-input-container', [
            const span(classes: 'command-palette-prompt', [.text('>')]),
            input(
              classes: 'command-palette-input',
              attributes: {
                'type': 'text',
                'placeholder': 'Type a command or search...',
                'value': _query,
                'aria-autocomplete': 'list',
                'aria-controls': 'command-palette-list',
                'aria-activedescendant': filtered.isNotEmpty ? 'cmd-item-$selectedIndex' : '',
                'spellcheck': 'false',
                'autocomplete': 'off',
              },
              events: {
                'input': (event) {
                  final target = event.target as web.HTMLInputElement;
                  setState(() {
                    _query = target.value;
                    _selectedIndex = 0;
                  });
                },
              },
            ),
          ]),
          div(
            id: 'command-palette-list',
            classes: 'command-palette-list',
            attributes: const {
              'role': 'listbox',
            },
            [
              if (filtered.isEmpty)
                const div(classes: 'command-palette-empty', [
                  .text('No matching commands found'),
                ])
              else
                for (var i = 0; i < filtered.length; i++)
                  _buildItem(filtered[i], index: i, isSelected: i == selectedIndex),
            ],
          ),
        ]),
      ],
    );
  }

  Component _buildItem(CommandPaletteAction action, {required int index, required bool isSelected}) {
    final shortcut = action.resolvedDisplayKey;

    return div(
      id: 'cmd-item-$index',
      classes: 'command-palette-item${isSelected ? ' active' : ''}',
      attributes: {
        'role': 'option',
        'aria-selected': isSelected ? 'true' : 'false',
        if (action.description.isNotEmpty) 'title': action.description,
      },
      events: {
        'mouseenter': (_) {
          if (_selectedIndex != index) {
            setState(() {
              _selectedIndex = index;
            });
          }
        },
        'click': (_) => _executeAction(action),
      },
      [
        span(classes: 'command-palette-item-title', [.text(action.label)]),
        if (shortcut.isNotEmpty) span(classes: 'command-palette-item-shortcut', [.text(shortcut)]),
      ],
    );
  }

  static List<StyleRule> get styles => [
    css('.command-palette-backdrop').styles(
      display: .flex,
      position: .fixed(top: 0.px, left: 0.px, right: 0.px, bottom: 0.px),
      zIndex: const ZIndex(10000),
      justifyContent: .center,
      alignItems: .start,
      backgroundColor: const Color('rgba(0, 0, 0, 0.45)'),
    ),
    css('.command-palette').styles(
      display: .flex,
      width: 580.px,
      maxWidth: 92.percent,
      maxHeight: 500.px,
      padding: .zero,
      margin: .only(top: 40.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(6.px),
      overflow: .hidden,
      shadow: BoxShadow(
        offsetX: 0.px,
        offsetY: 10.px,
        blur: 28.px,
        color: const Color('rgba(0, 0, 0, 0.35)'),
      ),
      flexDirection: .column,
      color: colorOnSurface,
      backgroundColor: colorSurface,
    ),
    css('.command-palette-input-container').styles(
      display: .flex,
      padding: .symmetric(vertical: 8.px, horizontal: 12.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      alignItems: .center,
      gap: Gap.all(8.px),
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.command-palette-prompt').styles(
      userSelect: .none,
      color: colorPrimary,
      fontFamily: monospaceFontFamily,
      fontSize: 15.px,
      fontWeight: .w700,
    ),
    css('.command-palette-input').styles(
      padding: .symmetric(vertical: 4.px, horizontal: 2.px),
      border: .unset,
      outline: .unset,
      flex: const .grow(1),
      color: colorOnSurface,
      fontFamily: defaultFontFamily,
      fontSize: 14.px,
      backgroundColor: const Color('transparent'),
    ),
    css('.command-palette-input::placeholder').styles(
      color: colorOnSurface.highlight(colorSurface, 0.4),
    ),
    css('.command-palette-list').styles(
      display: .flex,
      minHeight: 0.px,
      padding: .symmetric(vertical: 4.px),
      overflow: const .only(y: .auto),
      flexDirection: .column,
    ),
    css('.command-palette-item').styles(
      display: .flex,
      minHeight: 32.px,
      padding: .symmetric(vertical: 6.px, horizontal: 14.px),
      cursor: .pointer,
      userSelect: .none,
      justifyContent: .spaceBetween,
      alignItems: .center,
      gap: Gap.all(16.px),
      color: colorOnSurface,
      fontSize: 13.px,
    ),
    css('.command-palette-item.active').styles(
      color: colorOnContainer,
      backgroundColor: colorContainer,
    ),
    css('.command-palette-item-title').styles(
      overflow: .hidden,
      textOverflow: .ellipsis,
      whiteSpace: .noWrap,
    ),
    css('.command-palette-item-shortcut').styles(
      padding: .symmetric(vertical: 2.px, horizontal: 6.px),
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(3.px),
      color: colorOnSurface.highlight(colorSurface, 0.2),
      fontFamily: monospaceFontFamily,
      fontSize: 11.px,
      whiteSpace: .noWrap,
      backgroundColor: colorSurface,
    ),
    css('.command-palette-item.active .command-palette-item-shortcut').styles(
      color: colorOnContainer,
      backgroundColor: colorSurface,
    ),
    css('.command-palette-empty').styles(
      padding: .symmetric(vertical: 20.px, horizontal: 16.px),
      color: colorOnSurface.highlight(colorSurface, 0.35),
      textAlign: .center,
      fontSize: 13.px,
    ),
  ];
}
