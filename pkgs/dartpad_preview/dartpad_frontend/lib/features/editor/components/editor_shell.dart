// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/components/split_panel.dart';
import 'editor_breadcrumbs.dart';
import 'editor_stack.dart';
import 'editor_tab_bar.dart';

/// Top-level layout shell that hosts the CodeMirror editor.
class EditorShell extends StatelessComponent {
  /// Creates the top-level editor layout.
  const EditorShell({
    required this.openTabs,
    required this.activeFile,
    required this.fileTree,
    required this.editorOverlay,
    required this.onSwitchFile,
    required this.onCloseFile,
    required this.bottomPanel,
    this.contextMenu,
    this.isEmbedMode = false,
    this.smallScreenPreviewPanel,
    super.key,
  }) : assert(
         openTabs == null || (onSwitchFile != null && onCloseFile != null),
         'Tab callbacks are required when editor tabs are available.',
       );

  /// The open editor tabs, or `null` while the workspace is being initialized.
  final List<EditorTab<Component>>? openTabs;

  /// The path of the active editor tab.
  final String activeFile;

  /// Switches to the editor tab at the provided path.
  final void Function(String path)? onSwitchFile;

  /// Closes the editor tab at the provided path.
  final bool Function(String path, {bool discardChanges})? onCloseFile;

  /// The file tree component to show in the side panel.
  final Component fileTree;

  /// A component displayed above the active editor content.
  final Component editorOverlay;

  /// Bottom panel (e.g. problems view) rendered below the editor.
  final Component bottomPanel;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  /// Whether the app is running in embed mode (`?embed=true`).
  ///
  /// When `true`, the file tree starts collapsed into a narrow rail with a
  /// toggle button.
  final bool isEmbedMode;

  /// The preview panel to show when the Output tab is active in a small-screen layout.
  /// When non-null, the preview panel replaces the editor content.
  final Component? smallScreenPreviewPanel;

  @override
  Component build(BuildContext context) {
    final openTabs = this.openTabs;
    final editorContent = main_(classes: 'editor-host', [
      SplitPanel(
        isVertical: true,
        useRatio: true,
        initialValue: 0.75,
        minValue: 0.3,
        maxValue: 0.85,
        canCollapseRight: true,
        left: div(classes: 'editor-area', [
          if (openTabs != null) ...[
            EditorTabBar(
              openTabs: openTabs,
              activeFile: activeFile,
              onSwitchFile: onSwitchFile!,
              onCloseFile: onCloseFile!,
              contextMenu: contextMenu,
            ),
            if (activeFile.isNotEmpty) EditorBreadcrumbs(path: activeFile),
            EditorStack(
              openTabs: openTabs,
              activeFile: activeFile,
              overlay: editorOverlay,
            ),
          ],
        ]),
        right: bottomPanel,
      ),
    ]);
    final Component rightContent = smallScreenPreviewPanel ?? editorContent;

    return div(classes: 'editor-shell', [
      SplitPanel(
        initialValue: 200,
        initialState: isEmbedMode ? const LeftCollapsed(200) : null,
        useRatio: false,
        minValue: 150,
        maxValue: 300,
        canCollapseLeft: true,
        left: fileTree,
        right: rightContent,
      ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-shell').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      minWidth: .zero,
      minHeight: .zero,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: colorContainer,
    ),
    css('.file-tree-pane').styles(
      display: .flex,
      minWidth: 100.px,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
    ),
    css('.editor-host').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: 0.px,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1),
    ),
    css('.editor-area').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
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
  ];
}
