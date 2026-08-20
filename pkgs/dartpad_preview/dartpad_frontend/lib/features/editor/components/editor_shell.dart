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
    _fileTreeCollapsed = component.isEmbedMode;
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

    // In embed mode with collapsed file tree, show a narrow rail instead of
    // the full SplitPanel with file tree.
    if (component.isEmbedMode && _fileTreeCollapsed) {
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
        editorContent,
      ]);
    }

    // In embed mode with expanded file tree, show the file tree with a
    // collapse button in its header area.
    if (component.isEmbedMode) {
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
          right: editorContent,
        ),
      ]);
    }

    // Standard (non-embed) layout.
    return div(classes: 'editor-shell', [
      SplitPanel(
        initialValue: 200,
        useRatio: false,
        minValue: 150,
        maxValue: 300,
        left: aside(classes: 'file-tree-pane', [component.fileTree]),
        right: editorContent,
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
