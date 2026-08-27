// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../../app_styles.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/icons.dart';

/// Displays open editor files and lets users switch between or close them.
final class EditorTabBar extends StatelessComponent {
  /// Creates an [EditorTabBar] for [openTabs].
  ///
  /// [confirmDiscard] can override the browser confirmation dialog, for
  /// example in tests.
  const EditorTabBar({
    required this.openTabs,
    required this.activeFile,
    required this.onSwitchFile,
    required this.onCloseFile,
    this.confirmDiscard,
    this.contextMenu,
    super.key,
  });

  /// The tabs displayed in the tab strip.
  final List<EditorTab<Component>> openTabs;

  /// The path of the active editor tab.
  final String activeFile;

  /// Switches to the editor tab at the provided path.
  final void Function(String path) onSwitchFile;

  /// Closes the editor tab at the provided path.
  final bool Function(String path, {bool discardChanges}) onCloseFile;

  /// Requests confirmation before discarding changes in the file at [path].
  final bool Function(String path)? confirmDiscard;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  bool _closeSingleTab(EditorTab<Component> tabToClose) {
    final discardChanges =
        tabToClose.hasUnsavedChanges &&
        (confirmDiscard?.call(tabToClose.path) ??
            web.window.confirm(
              'Discard unsaved changes in ${tabToClose.name}?',
            ));
    if (tabToClose.hasUnsavedChanges && !discardChanges) {
      return false;
    }
    return onCloseFile(
      tabToClose.path,
      discardChanges: discardChanges,
    );
  }

  void _closeOtherTabs(EditorTab<Component> keepTab) {
    final tabsToClose = openTabs.where((t) => t.path != keepTab.path).toList();
    for (final t in tabsToClose) {
      if (!_closeSingleTab(t)) {
        break;
      }
    }
  }

  void _closeAllTabs() {
    for (final t in List.of(openTabs)) {
      if (!_closeSingleTab(t)) {
        break;
      }
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'editor-tab-bar',
      events: {
        'contextmenu': _handleTabBarContextMenu,
      },
      [
        for (final tab in openTabs)
          div(
            key: ValueKey('tab-${tab.path}'),
            classes: [
              'editor-tab',
              if (tab.path == activeFile) 'active',
              if (tab.hasUnsavedChanges) 'dirty',
            ].join(' '),
            attributes: {
              'title': tab.path,
              'tabindex': '0',
              'role': 'tab',
              'aria-selected': tab.path == activeFile ? 'true' : 'false',
            },
            events: {
              'click': (_) => onSwitchFile(tab.path),
              'keydown': (event) {
                final keyboardEvent = event as web.KeyboardEvent;
                if (keyboardEvent.key == 'Enter' || keyboardEvent.key == ' ') {
                  onSwitchFile(tab.path);
                }
              },
              'contextmenu': (event) => _handleTabContextMenu(event, tab),
            },
            [
              span(classes: 'editor-tab-name', [.text(tab.name)]),
              if (tab.hasUnsavedChanges) const span(classes: 'editor-tab-dirty-dot', []),
              button(
                classes: 'editor-tab-action close',
                attributes: {
                  'title': 'Close tab',
                  'aria-label': 'Close ${tab.name}',
                },
                events: {
                  'click': (event) {
                    event.stopPropagation();
                    _closeSingleTab(tab);
                  },
                },
                [const Icon('close', size: 12)],
              ),
            ],
          ),
      ],
    );
  }

  void _handleTabBarContextMenu(web.Event event) {
    final menu = contextMenu;
    if (menu == null) {
      return;
    }
    final mouseEvent = event as web.MouseEvent;
    final target = mouseEvent.target as web.Element?;
    if (target?.closest('.editor-tab') != null) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    menu.show(
      mouseEvent.clientX.toDouble(),
      mouseEvent.clientY.toDouble(),
      _buildTabBarContextMenuItems(),
    );
  }

  List<ContextMenuEntry> _buildTabBarContextMenuItems() {
    return [
      ContextMenuItem(
        label: 'Close all tabs',
        disabled: openTabs.isEmpty,
        onPressed: _closeAllTabs,
      ),
    ];
  }

  void _handleTabContextMenu(web.Event event, EditorTab<Component> tab) {
    final menu = contextMenu;
    if (menu == null) {
      return;
    }
    final mouseEvent = event as web.MouseEvent;
    event.preventDefault();
    event.stopPropagation();
    menu.show(
      mouseEvent.clientX.toDouble(),
      mouseEvent.clientY.toDouble(),
      _buildTabContextMenuItems(tab),
    );
  }

  List<ContextMenuEntry> _buildTabContextMenuItems(EditorTab<Component> tab) {
    final hasOthers = openTabs.length > 1;

    return [
      ContextMenuItem(
        label: 'Close',
        onPressed: () => _closeSingleTab(tab),
      ),
      ContextMenuItem(
        label: 'Close others',
        disabled: !hasOthers,
        onPressed: () => _closeOtherTabs(tab),
      ),
      ContextMenuItem(
        label: 'Close all',
        onPressed: _closeAllTabs,
      ),
      const ContextMenuDivider(),
      ContextMenuItem(
        label: 'Copy path',
        onPressed: () {
          unawaited(web.window.navigator.clipboard.writeText(tab.path).toDart.catchError((Object? _) => null));
        },
      ),
    ];
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-tab-bar', [
      css('&').styles(
        display: .flex,
        minHeight: 38.px,
        overflow: const .only(x: .auto, y: .hidden),
        flex: const .shrink(0),
        backgroundColor: colorSurface,
      ),
      css('.editor-tab', [
        css('&').styles(
          display: .flex,
          minWidth: 96.px,
          maxWidth: 180.px,
          padding: .only(left: 12.px, right: 8.px),
          border: .only(
            top: .solid(color: Colors.transparent, width: 2.px),
          ),
          cursor: .pointer,
          userSelect: .none,
          alignItems: .center,
          gap: .all(6.px),
          color: colorOnContainer,
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.1),
        ),
        css('&:hover').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.15),
        ),
        css('&.active').styles(
          color: colorOnContainer,
          backgroundColor: colorContainer,
        ),
        css('&.active:hover').styles(
          backgroundColor: colorContainer.highlight(colorOnContainer, 0.05),
        ),
        css('.editor-tab-name').styles(
          minWidth: .zero,
          overflow: .hidden,
          flex: const Flex(grow: 1, basis: .zero),
          fontFamily: const .list([FontFamily('Consolas'), FontFamilies.monospace]),
          fontSize: 12.px,
          textOverflow: .ellipsis,
          whiteSpace: .noWrap,
        ),
        css('.editor-tab-dirty-dot').styles(
          width: 7.px,
          height: 7.px,
          radius: .circular(4.px),
          flex: const .shrink(0),
          backgroundColor: colorPrimary,
        ),
        css('.editor-tab-action', [
          css('&').styles(
            display: .flex,
            width: 18.px,
            height: 18.px,
            padding: .zero,
            border: .none,
            radius: .circular(4.px),
            cursor: .pointer,
            justifyContent: .center,
            alignItems: .center,
            color: colorOnSurface,
            fontSize: 11.px,
            backgroundColor: Colors.transparent,
          ),
          css('&:hover').styles(
            color: const Color('#ffffff'),
            backgroundColor: const Color('#3a3a3a'),
          ),
          css('&.close:hover').styles(
            color: colorError,
            backgroundColor: colorSurface,
          ),
        ]),
      ]),
    ]),
  ];
}
