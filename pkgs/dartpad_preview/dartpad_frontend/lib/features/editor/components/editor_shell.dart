// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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

  /// Switches to the editor tab at the provided path.
  final void Function(String path)? onSwitchFile;

  /// Closes the editor tab at the provided path.
  final bool Function(String path, {bool discardChanges})? onCloseFile;

  /// Human-readable label for the current status.
  final String bootstrapLabel;

  @override
  Component build(BuildContext context) {
    final openTabs = this.openTabs;
    return div(classes: 'ide-shell', [
      main_(classes: 'editor-host', [
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
      div(
        classes: [
          'status-bar',
          if (errorMessage != null) 'error',
        ].join(' '),
        [
          .text(errorMessage ?? bootstrapLabel),
        ],
      ),
    ]);
  }
}
