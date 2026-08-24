// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../../app_styles.dart';
import '../../shared/components/split_panel.dart';
import '../../shared/icons.dart';
import 'editor_stack.dart';
import 'editor_tabs.dart';

/// Top-level layout shell that hosts the CodeMirror editor.
class EditorShell extends StatefulComponent {
  /// Creates the top-level editor layout.
  const EditorShell({
    required this.openTabs,
    required this.activeFile,
    required this.fileTree,
    required this.editorOverlay,
    required this.onSwitchFile,
    required this.onCloseFile,
    required this.bottomPanel,
    this.isEmbedMode = false,
    this.mobileTabBar,
    this.mobilePreviewPanel,
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

  /// The workspace file tree.
  final Component fileTree;

  /// A component displayed above the active editor content.
  final Component editorOverlay;

  /// Bottom panel (e.g. problems view) rendered below the editor.
  final Component bottomPanel;

  /// Whether the app is running in embed mode (`?embed=true`).
  ///
  /// When `true`, the file tree starts collapsed into a narrow rail with a
  /// toggle button.
  final bool isEmbedMode;

  /// Optional tab bar (Code / Output) rendered above the editor in mobile
  /// layout. When provided, the tab bar is placed to the right of the file
  /// tree so it does not span the full screen width.
  final Component? mobileTabBar;

  /// The preview panel to show when the Output tab is active in mobile layout.
  /// When non-null, the preview panel replaces the editor content.
  final Component? mobilePreviewPanel;

  @override
  State<EditorShell> createState() => _EditorShellState();

  @css
  static List<StyleRule> get styles => _EditorShellState.styles;
}

class _EditorShellState extends State<EditorShell> {
  late bool _fileTreeCollapsed;

  @override
  void initState() {
    super.initState();
    _fileTreeCollapsed = component.isEmbedMode || component.mobileTabBar != null;
  }

  void _toggleFileTree() {
    setState(() {
      _fileTreeCollapsed = !_fileTreeCollapsed;
    });
  }

  @override
  Component build(BuildContext context) {
    final openTabs = component.openTabs;

    final editorContent = main_(classes: 'editor-host', [
      SplitPanel(
        isVertical: true,
        useRatio: true,
        initialValue: 0.75,
        minValue: 0.3,
        maxValue: 0.9,
        left: div(classes: 'editor-area', [
          if (openTabs != null) ...[
            EditorTabs(
              openTabs: openTabs,
              activeFile: component.activeFile,
              onSwitchFile: component.onSwitchFile!,
              onCloseFile: component.onCloseFile!,
            ),
            EditorStack(
              openTabs: openTabs,
              activeFile: component.activeFile,
              overlay: component.editorOverlay,
            ),
          ],
        ]),
        right: component.bottomPanel,
      ),
    ]);
    // Determine the right-hand content: in mobile mode wrap with the tab bar,
    // otherwise just the editor.
    final Component rightContent;
    if (component.mobileTabBar != null) {
      rightContent = div(classes: 'editor-shell-mobile-content', [
        component.mobileTabBar!,
        if (component.mobilePreviewPanel != null) component.mobilePreviewPanel! else editorContent,
      ]);
    } else if (component.mobilePreviewPanel != null) {
      rightContent = component.mobilePreviewPanel!;
    } else {
      rightContent = editorContent;
    }

    // Collapsed file tree: show a narrow rail with a toggle button.
    if (_fileTreeCollapsed) {
      return div(classes: 'editor-shell', [
        aside(classes: 'file-tree-rail', [
          button(
            classes: 'file-tree-rail-button',
            attributes: {
              'title': 'Show file tree',
              'aria-label': 'Show file tree',
            },
            onClick: _toggleFileTree,
            [const Icon('folder_open', size: 18)],
          ),
        ]),
        rightContent,
      ]);
    }

    // Expanded file tree with collapse button.
    return div(classes: 'editor-shell', [
      SplitPanel(
        initialValue: 200,
        useRatio: false,
        minValue: 150,
        maxValue: 300,
        left: aside(classes: 'file-tree-pane', [
          div(classes: 'file-tree-collapse-bar', [
            button(
              classes: 'file-tree-rail-button',
              attributes: {
                'title': 'Hide file tree',
                'aria-label': 'Hide file tree',
              },
              onClick: _toggleFileTree,
              [const Icon('chevron_left', size: 18)],
            ),
          ]),
          component.fileTree,
        ]),
        right: rightContent,
      ),
    ]);
  }

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

    // -- Mobile layout: content column to the right of the file tree --
    css('.editor-shell-mobile-content').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
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

    // -- Embed mode: collapse bar above file tree when expanded --
    css('.file-tree-collapse-bar').styles(
      display: .flex,
      height: 32.px,
      minHeight: 32.px,
      padding: .symmetric(horizontal: 4.px),
      border: .only(
        bottom: .solid(color: colorBorder, width: 1.px),
      ),
      justifyContent: .end,
      alignItems: .center,
      flex: const .shrink(0),
      backgroundColor: colorSurface,
    ),
  ];
}
