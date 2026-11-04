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

  @override
  Component build(BuildContext context) {
    final isEmbed = panels.mode == WorkspaceMode.embed;
    return div(classes: 'workspace-layout${isLargeScreen ? '' : ' editor-shell-small'}', [
      //TODO: move css class to editor and not on top level here
      //TODO: find out the concuantion stuff if it makes sense
      SplitPanel(
        state: panels.fileTreeListenable,
        onStateChanged: panels.updateFileTree,
        useRatio: false,
        minValue: 150,
        maxValue: 300,
        canCollapseLeft: true,
        left: div(id: 'editor-file-tree', classes: 'file-tree-panel', [fileTree]),
        right: div(classes: 'workspace-content', [
          // The same ancestors host the iframe in every layout. Even reattaching
          // the same iframe node would discard its running browsing context.

          SplitPanel(
            state: panels.previewListenable,
            presentationState: isLargeScreen
                ? null
                : showOutput
                ? LeftHidden(panels.preview.value)
                : RightHidden(panels.preview.value),
            onStateChanged: panels.updatePreview,
            canCollapseRight:
                isLargeScreen, //TODO: make vairalbeNames more explicit or at least leave commetns explaining stuff
            minValue: isEmbed
                ? 0.05
                : 0.3, //TODO: leave explanation for legacy values, puthtme imn variables, not magic numbers
            maxValue: isEmbed ? 0.95 : 0.85,
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
