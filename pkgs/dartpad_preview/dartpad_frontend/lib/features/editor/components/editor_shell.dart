// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/components/panel_visibility.dart';
import '../../shared/components/split_panel.dart';
import '../../shared/icons.dart';
import '../../shared/panel_layout_controller.dart';
import '../../shared/panel_presentation_state.dart';
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
    required this.panelController,
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

  /// Shared split and bottom-tab state, retained when this layout is remounted.
  final PanelLayoutController panelController;

  /// The preview panel to show when the Output tab is active in a small-screen layout.
  /// When non-null, the preview panel replaces the editor content.
  final Component? smallScreenPreviewPanel;

  @override
  Component build(BuildContext context) {
    final openTabs = this.openTabs;
    final activeTab = openTabs?.where((tab) => tab.path == activeFile).firstOrNull;
    final breadcrumbPath = activeTab?.displayPath ?? activeFile;
    final editor = div(classes: 'editor-area', [
      if (openTabs != null) ...[
        ValueListenableBuilder(
          listenable: panelController.editorNavigationListenable,
          builder: (_, navigation) {
            // Reveal grouped navigation temporarily when another file opens.
            return PanelVisibility(
              id: 'editor-navigation-panel',
              visible: openTabs.length > 1 || navigation == PanelPresentationState.expanded,
              child: Component.fragment([
                EditorTabBar(
                  openTabs: openTabs,
                  activeFile: activeFile,
                  onSwitchFile: onSwitchFile!,
                  onCloseFile: onCloseFile!,
                  contextMenu: contextMenu,
                ),
                if (activeFile.isNotEmpty) EditorBreadcrumbs(path: breadcrumbPath),
              ]),
            );
          },
        ),
        EditorStack(
          openTabs: openTabs,
          activeFile: activeFile,
          overlay: div(classes: 'editor-overlays', [
            editorOverlay,
            _buildFileTreeFloatingButton(),
          ]),
        ),
      ],
    ]);
    final editorContent = main_(classes: 'editor-host', [
      SplitPanel(
        isVertical: true,
        useRatio: true,
        state: panelController.bottomSplitListenable,
        onStateChanged: panelController.updateBottomSplit,
        minValue: 0.3,
        maxValue: 0.85,
        canCollapseRight: true,
        left: editor,
        right: bottomPanel,
      ),
    ]);
    final Component rightContent = smallScreenPreviewPanel ?? editorContent;

    return ValueListenableBuilder(
      listenable: panelController.layoutListenable,
      builder: (_, _) => div(
        classes: 'editor-shell${panelController.isSmallScreen ? ' editor-shell-small' : ''}',
        [
          SplitPanel(
            state: panelController.fileTreeListenable,
            onStateChanged: panelController.updateFileTree,
            useRatio: false,
            minValue: 150,
            maxValue: 300,
            canCollapseLeft: true,
            left: div(id: 'editor-file-tree', classes: 'file-tree-panel', [fileTree]),
            right: rightContent,
          ),
        ],
      ),
    );
  }

  Component _buildFileTreeFloatingButton() => ValueListenableBuilder(
    listenable: panelController.layoutListenable,
    builder: (_, _) => panelController.isSmallScreen
        ? ValueListenableBuilder(
            listenable: panelController.fileTreeListenable,
            builder: (_, state) => state.isSplit
                ? const Component.fragment([])
                : button(
                    classes: 'file-tree-floating-button',
                    attributes: {
                      'type': 'button',
                      'title': 'Show file tree',
                      'aria-label': 'Show file tree',
                      'aria-expanded': '${state.isSplit}',
                      'aria-controls': 'editor-file-tree',
                    },
                    onClick: panelController.toggleFileTree,
                    const [Icon('folder_open', size: 22)],
                  ),
          )
        : const Component.fragment([]),
  );

  @css
  static List<StyleRule> get styles => [
    css('.editor-shell').styles(
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
    css('.file-tree-floating-button').styles(
      display: .flex,
      position: .absolute(top: 16.px, left: 16.px),
      zIndex: const ZIndex(30),
      width: 44.px,
      height: 44.px,
      padding: .zero,
      border: .all(color: colorBorder, width: 1.px),
      radius: .circular(8.px),
      shadow: BoxShadow(offsetX: 0.px, offsetY: 2.px, blur: 6.px, color: const Color.rgba(0, 0, 0, 0.2)),
      cursor: .pointer,
      justifyContent: .center,
      alignItems: .center,
      color: colorOnSurface,
      backgroundColor: colorSurface,
    ),
    css('.file-tree-floating-button:hover').styles(
      backgroundColor: colorSurface.highlight(colorOnSurface, 0.1),
    ),
    css('.file-tree-floating-button:focus-visible').styles(
      outline: Outline(style: .solid, color: colorOnSurface, width: OutlineWidth(2.px)),
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
