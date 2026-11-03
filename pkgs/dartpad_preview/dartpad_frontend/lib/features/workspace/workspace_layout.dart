// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../app_styles.dart';
import '../shared/components/split_panel.dart';
import '../shared/panel_layout_controller.dart';
import '../shared/workspace_mode.dart';

/// Keeps the editor and preview mounted across tab and screen-size changes.
final class WorkspaceLayout extends StatelessComponent {
  const WorkspaceLayout({
    required this.fileTree,
    required this.editor,
    required this.preview,
    required this.panels,
    required this.showOutput,
    super.key,
  });

  final Component fileTree;
  final Component editor;
  final Component preview;
  final PanelLayoutController panels;
  final bool showOutput;

  // Keep file navigation usable without letting it dominate the workspace.
  static const _minFileTreeWidth = 150.0;
  static const _maxFileTreeWidth = 300.0;

  // SplitPanel's ratio is the editor's share of the editor/preview width.
  // Standalone reserves at least 30% for editing and 15% for the preview.
  static const _minStandaloneEditorFraction = 0.3;
  static const _maxStandaloneEditorFraction = 0.85;

  // Embeds support the legacy `split=5` through `split=95` URL range,
  // allowing either pane to fill most of the available space.
  static const _minEmbedEditorFraction = 0.05;
  static const _maxEmbedEditorFraction = 0.95;

  @override
  Component build(BuildContext context) {
    final isEmbed = panels.mode == WorkspaceMode.embed;
    return ValueListenableBuilder(
      listenable: panels.layoutListenable,
      builder: (_, _) {
        final isLargeScreen = !panels.isSmallScreen;
        return div(classes: 'workspace-layout${isLargeScreen ? '' : ' workspace-layout-small'}', [
          SplitPanel(
            state: panels.fileTreeListenable,
            onStateChanged: panels.updateFileTree,
            useRatio: false,
            minValue: _minFileTreeWidth,
            maxValue: _maxFileTreeWidth,
            canCollapseLeft: isLargeScreen,
            left: _FileTreePanel(controller: panels, child: fileTree),
            right: ValueListenableBuilder(
              listenable: panels.fileTreeListenable,
              builder: (_, fileTree) => div(
                classes: 'workspace-content editor-shell-content',
                attributes: {if (!isLargeScreen && fileTree.isSplit) 'inert': ''},
                [
                  // The same ancestors host the iframe in every layout. Even reattaching
                  // the same iframe node would discard its running browsing context.
                  SplitPanel(
                    state: _PreviewSplitListenable(
                      panels.previewListenable,
                      isLargeScreen: isLargeScreen,
                      showOutput: showOutput,
                    ),
                    onStateChanged: panels.updatePreview,
                    // The right pane is the preview. Only large screens use its
                    // collapsed rail; small screens switch panes through tabs.
                    canCollapseRight: isLargeScreen,
                    minValue: isEmbed ? _minEmbedEditorFraction : _minStandaloneEditorFraction,
                    maxValue: isEmbed ? _maxEmbedEditorFraction : _maxStandaloneEditorFraction,
                    left: editor,
                    right: preview,
                  ),
                ],
              ),
            ),
          ),
          if (!isLargeScreen)
            ValueListenableBuilder(
              listenable: panels.fileTreeListenable,
              builder: (_, fileTree) => Component.fragment([
                if (fileTree.isSplit)
                  button(
                    classes: 'file-tree-drawer-backdrop',
                    attributes: const {'type': 'button', 'aria-label': 'Close file explorer', 'tabindex': '-1'},
                    onClick: panels.closeSmallScreenFileTree,
                    const [],
                  ),
              ]),
            ),
        ]);
      },
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.workspace-layout').styles(
      display: .flex,
      position: const .relative(),
      width: 100.percent,
      height: 100.percent,
      minWidth: .zero,
      minHeight: .zero,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: colorContainer,
    ),
    css('.editor-shell-small .editor-tab-bar').styles(
      display: .none,
    ),
    css('.file-tree-panel').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
    ),
    css('.file-tree-panel > .file-tree-rail').styles(
      flex: const Flex(grow: 1, shrink: 0),
    ),
    css('.editor-shell-content').styles(
      display: .flex,
      position: const .relative(),
      zIndex: const ZIndex(0),
      minWidth: .zero,
      minHeight: .zero,
    ),
    css('.workspace-layout-small > .file-tree-panel').styles(
      position: const .absolute(top: .zero, bottom: .zero, left: .zero),
      zIndex: const ZIndex(20),
      width: (200 / 3).percent,
      outline: const Outline(style: .none),
      overflow: .hidden,
      shadow: BoxShadow(offsetX: 4.px, offsetY: .zero, blur: 16.px, color: const .rgba(0, 0, 0, 0.2)),
      backgroundColor: colorContainer,
    ),
    css('.workspace-layout-small > .drag-handle').styles(display: .none),
    css('.file-tree-drawer-backdrop').styles(
      position: const .absolute(top: .zero, right: .zero, bottom: .zero, left: .zero),
      zIndex: const ZIndex(10),
      padding: .zero,
      border: .none,
      cursor: .pointer,
      backgroundColor: colorBackdrop,
    ),
    css('.workspace-content').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      overflow: .hidden,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}

/// Keeps drawer focus local without rebuilding the editor or preview beneath it.
final class _FileTreePanel extends StatefulComponent {
  const _FileTreePanel({required this.controller, required this.child});

  final PanelLayoutController controller;
  final Component child;

  @override
  State<_FileTreePanel> createState() => _FileTreePanelState();
}

final class _FileTreePanelState extends State<_FileTreePanel> {
  final _panelKey = GlobalNodeKey();
  bool _drawerOpen = false;
  web.HTMLElement? _returnFocus;

  void _addListeners(PanelLayoutController controller) {
    controller.fileTreeListenable.addListener(_onPresentationChanged);
    controller.layoutListenable.addListener(_onPresentationChanged);
  }

  void _removeListeners(PanelLayoutController controller) {
    controller.fileTreeListenable.removeListener(_onPresentationChanged);
    controller.layoutListenable.removeListener(_onPresentationChanged);
  }

  @override
  void initState() {
    super.initState();
    _addListeners(component.controller);
    _onPresentationChanged();
  }

  @override
  void didUpdateComponent(_FileTreePanel oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.controller != component.controller) {
      _removeListeners(oldComponent.controller);
      _addListeners(component.controller);
      _onPresentationChanged();
    }
  }

  void _onPresentationChanged() {
    final open = component.controller.isSmallScreen && component.controller.fileTree.isSplit;
    if (open == _drawerOpen) {
      return;
    }
    if (open) {
      _returnFocus = web.document.activeElement as web.HTMLElement?;
    }
    setState(() => _drawerOpen = open);
    context.binding.addPostFrameCallback(() {
      if (!mounted || _drawerOpen != open) {
        return;
      }
      if (open) {
        (_panelKey.currentNode as web.HTMLElement?)?.focus(web.FocusOptions(preventScroll: true));
      } else if (component.controller.isSmallScreen && (_returnFocus?.isConnected ?? false)) {
        _returnFocus?.focus(web.FocusOptions(preventScroll: true));
      }
    });
  }

  void _onKeyDown(web.Event event) {
    if (!_drawerOpen || event.defaultPrevented) {
      return;
    }
    final key = event as web.KeyboardEvent;
    if (key.key == 'Escape') {
      key.preventDefault();
      key.stopPropagation();
      component.controller.closeSmallScreenFileTree();
    } else if (key.key == 'Tab') {
      final panel = _panelKey.currentNode as web.HTMLElement?;
      if (panel == null) {
        return;
      }
      final nodes = panel.querySelectorAll(
        'button:not(:disabled), [href], input:not(:disabled), select, textarea, [tabindex="0"]',
      );
      final focusable = [
        for (var i = 0; i < nodes.length; i++)
          if ((nodes.item(i)! as web.HTMLElement).getClientRects().length > 0) nodes.item(i)! as web.HTMLElement,
      ];
      if (focusable.isEmpty) {
        key.preventDefault();
      } else if (web.document.activeElement == panel ||
          web.document.activeElement == (key.shiftKey ? focusable.first : focusable.last)) {
        key.preventDefault();
        (key.shiftKey ? focusable.last : focusable.first).focus(web.FocusOptions(preventScroll: true));
      }
    }
  }

  @override
  Component build(BuildContext context) => div(
    key: _panelKey,
    id: 'editor-file-tree',
    classes: 'file-tree-panel',
    attributes: {
      if (_drawerOpen) ...{'role': 'dialog', 'aria-modal': 'true', 'aria-label': 'File explorer', 'tabindex': '-1'},
    },
    events: {'keydown': _onKeyDown},
    [component.child],
  );

  @override
  void dispose() {
    _removeListeners(component.controller);
    super.dispose();
  }
}

/// Adapts the desktop split to the selected mobile tab, keeping its current size.
/// Notifications come from the desktop split; tab and screen-size changes replace
/// this adapter when [WorkspaceLayout] rebuilds. Neither changes the saved split.
final class _PreviewSplitListenable implements ValueListenable<SplitState> {
  const _PreviewSplitListenable(this._preview, {required this.isLargeScreen, required this.showOutput});

  final ValueListenable<SplitState> _preview;
  final bool isLargeScreen;
  final bool showOutput;

  @override
  SplitState get value {
    final state = _preview.value;
    if (isLargeScreen) {
      return state;
    }
    return showOutput ? LeftHidden(state.value) : RightHidden(state.value);
  }

  @override
  void addListener(VoidCallback listener) => _preview.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _preview.removeListener(listener);
}
