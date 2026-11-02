// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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
    return SplitPanel(
      state: panels.fileTreeListenable,
      onStateChanged: panels.updateFileTree,
      useRatio: false,
      minValue: 150,
      maxValue: 300,
      canCollapseLeft: true,
      left: fileTree,
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
          canCollapseRight: isLargeScreen,
          minValue: isEmbed ? 0.05 : 0.3,
          maxValue: isEmbed ? 0.95 : 0.85,
          left: editor,
          right: preview,
        ),
      ]),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.workspace-content').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      overflow: .hidden,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
