// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../../shared/components/split_panel.dart';
import 'editor_stack.dart';
import 'editor_tabs.dart';

/// Top-level layout shell that hosts the CodeMirror editor and the bootstrap
/// status indicator.
class EditorShell extends StatelessComponent {
  /// Creates the top-level editor layout.
  const EditorShell({
    required this.openTabs,
    required this.activeFile,
    required this.errorMessage,
    required this.warningMessage,
    required this.fileTree,
    required this.onSwitchFile,
    required this.onCloseFile,
    required this.bootstrapLabel,
    super.key,
  }) : assert(
         openTabs == null || (onSwitchFile != null && onCloseFile != null),
         'Tab callbacks are required when editor tabs are available.',
       );

  /// The open editor tabs, or `null` while the workspace is being initialized.
  final List<EditorTab<Component>>? openTabs;

  /// The path of the active editor tab.
  final String activeFile;

  /// The latest user-facing editor error, or `null` if there is none.
  final String? errorMessage;

  /// The latest user-facing editor warning, or `null` if there is none.
  final String? warningMessage;

  /// Switches to the editor tab at the provided path.
  final void Function(String path)? onSwitchFile;

  /// Closes the editor tab at the provided path.
  final bool Function(String path, {bool discardChanges})? onCloseFile;

  /// The workspace file tree.
  final Component fileTree;

  /// Human-readable label for the current status.
  final String bootstrapLabel;

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
              ),
            ],
          ]),
        ),
      ]),
      div(
        classes: [
          'status-bar',
          if (errorMessage != null) 'error',
          if (errorMessage == null && warningMessage != null) 'warning',
        ].join(' '),
        [
          .text(errorMessage ?? warningMessage ?? bootstrapLabel),
        ],
      ),
    ]);
  }

  @css
  static List<StyleRule> get styles => [
    css('.ide-shell').styles(
      display: .flex,
      width: 100.percent,
      height: 100.vh,
      flexDirection: .column,
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
    css('.status-bar', [
      css('&').styles(
        minHeight: 24.px,
        padding: .symmetric(horizontal: 10.px),
        border: .only(
          top: .solid(color: const Color('#303030'), width: 1.px),
        ),
        overflow: .hidden,
        color: const Color('#858585'),
        fontSize: 11.px,
        lineHeight: 24.px,
        textOverflow: .ellipsis,
        whiteSpace: .noWrap,
        backgroundColor: const Color('#181818'),
      ),
      css('&.error').styles(color: const Color('#ff8a8a')),
      css('&.warning').styles(color: const Color('#e5c07b')),
    ]),
  ];
}
