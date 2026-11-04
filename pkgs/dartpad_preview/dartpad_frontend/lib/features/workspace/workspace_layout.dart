// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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
    required this.isLargeScreen,
    required this.showOutput,
    super.key,
  });

  final Component fileTree;
  final Component editor;
  final Component preview;
  final PanelLayoutController panels;
  final bool isLargeScreen;
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
    return div(classes: 'workspace-layout', [
      SplitPanel(
        state: panels.fileTreeListenable,
        onStateChanged: panels.updateFileTree,
        useRatio: false,
        minValue: _minFileTreeWidth,
        maxValue: _maxFileTreeWidth,
        canCollapseLeft: true,
        left: div(id: 'editor-file-tree', classes: 'file-tree-panel', [fileTree]),
        right: div(classes: 'workspace-content', [
          // The same ancestors host the iframe in every layout. Even reattaching
          // the same iframe node would discard its running browsing context.
          SplitPanel(
            state: panels.previewListenable,
            // Code/Output tabs show one pane at a time on small screens,
            // without changing the split restored on a large screen.
            presentationState: isLargeScreen
                ? null
                : showOutput
                ? LeftHidden(panels.preview.value)
                : RightHidden(panels.preview.value),
            onStateChanged: panels.updatePreview,
            // The right pane is the preview. Only large screens use its
            // collapsed rail; small screens switch panes through tabs.
            canCollapseRight: isLargeScreen,
            minValue: isEmbed ? _minEmbedEditorFraction : _minStandaloneEditorFraction,
            maxValue: isEmbed ? _maxEmbedEditorFraction : _maxStandaloneEditorFraction,
            left: editor,
            right: preview,
          ),
        ]),
      ),
    ]);
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
    css('.file-tree-panel').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
    ),
    css('.file-tree-panel > .file-tree-rail').styles(
      flex: const Flex(grow: 1, shrink: 0),
    ),
    // -- Embed mode: collapsed file-tree rail --
    css('.file-tree-rail').styles(
      display: .flex,
      width: 36.px,
      minWidth: 36.px,
      padding: .only(top: 8.px),
      border: .only(
        right: .solid(color: colorBorder, width: 1.px),
      ),
      flexDirection: .column,
      alignItems: .center,
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
    css('.file-tree-rail-button').styles(
      display: .flex,
      width: 28.px,
      height: 28.px,
      padding: .zero,
      border: .none,
      radius: .circular(6.px),
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      color: colorOnSurface,
      backgroundColor: Colors.transparent,
    ),
    css('.file-tree-rail-button:hover').styles(
      backgroundColor: colorBorder,
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
