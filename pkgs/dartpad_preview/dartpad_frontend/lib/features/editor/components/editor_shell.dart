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
    required this.editorOverlay,
    required this.onSwitchFile,
    required this.onCloseFile,
    required this.bottomPanel,
    this.contextMenu,
    required this.panelController,
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

  /// A component displayed above the active editor content.
  final Component editorOverlay;

  /// Bottom panel (e.g. problems view) rendered below the editor.
  final Component bottomPanel;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  /// Shared bottom-panel and editor-navigation state.
  final PanelLayoutController panelController;

  // Reserve at least 30% of the height for the editor and 15% for the bottom panel.
  static const _minEditorHeightFraction = 0.3;
  static const _maxEditorHeightFraction = 0.85;

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
                ValueListenableBuilder(
                  listenable: panelController.layoutListenable,
                  builder: (_, _) => Component.fragment([
                    // Mobile file navigation uses the file explorer instead of a tab strip.
                    if (!panelController.isSmallScreen)
                      EditorTabBar(
                        openTabs: openTabs,
                        activeFile: activeFile,
                        onSwitchFile: onSwitchFile!,
                        onCloseFile: onCloseFile!,
                        contextMenu: contextMenu,
                      ),
                  ]),
                ),
                if (activeFile.isNotEmpty) EditorBreadcrumbs(path: breadcrumbPath),
              ]),
            );
          },
        ),
        EditorStack(
          openTabs: openTabs,
          activeFile: activeFile,
          overlay: editorOverlay,
        ),
      ],
    ]);
    return ValueListenableBuilder(
      listenable: panelController.layoutListenable,
      builder: (_, _) => main_(
        classes: [
          'editor-shell',
          'editor-host',
          if (panelController.isSmallScreen) 'editor-shell-small',
        ].join(' '),
        [
          SplitPanel(
            isVertical: true,
            useRatio: true,
            state: panelController.bottomSplitListenable,
            onStateChanged: panelController.updateBottomSplit,
            minValue: _minEditorHeightFraction,
            maxValue: _maxEditorHeightFraction,
            canCollapseRight: true,
            left: editor,
            right: bottomPanel,
          ),
        ],
      ),
    );
  }

  @css
  static List<StyleRule> get styles => [
    css('.editor-host').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: 0.px,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1),
      backgroundColor: colorContainer,
    ),
    css('.editor-area').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      overflow: .hidden,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
