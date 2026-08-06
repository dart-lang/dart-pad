// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/components/split_panel.dart';
import 'editor_stack.dart';
import 'editor_tabs.dart';

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

  @override
  Component build(BuildContext context) {
    final openTabs = this.openTabs;
    return div(classes: 'ide-shell', [
      div(classes: 'workspace-shell', [
        SplitPanel(
          initialValue: 200,
          useRatio: false,
          minValue: 150,
          maxValue: 300,
          left: aside(classes: 'file-tree-pane', [fileTree]),
          right: main_(classes: 'editor-host', [
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
                    activeFile: activeFile,
                    onSwitchFile: onSwitchFile!,
                    onCloseFile: onCloseFile!,
                  ),
                  EditorStack(
                    openTabs: openTabs,
                    activeFile: activeFile,
                    overlay: editorOverlay,
                  ),
                ],
              ]),
              right: bottomPanel,
            ),
          ]),
        ),
      ]),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.ide-shell').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
      backgroundColor: const Color('#1e1e1e'),
    ),
    css('.workspace-shell').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.file-tree-pane').styles(
      display: .flex,
      minWidth: 100.px,
      minHeight: .zero,
      border: .only(
        right: .solid(color: const Color('#303030'), width: 1.px),
      ),
      overflow: .hidden,
      flexDirection: .column,
      backgroundColor: const Color('#181818'),
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
  ];
}
