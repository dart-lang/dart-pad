// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

import '../../bottom_panel/views/bottom_panel.dart';
import '../view_models/editor_host_view_model.dart';
import '../view_models/tabs_view_model.dart';
import 'editor_shell.dart';

/// View counterpart to [EditorHostViewModel].
///
/// Assembles the [EditorShell] (tabs, editor stack) together with the
/// [BottomPanel] (problems view) into a single layout.
///
/// Both [tabs] and [editorHostViewModel] are observed internally via
/// [ListenableBuilder] so that only the affected subtrees rebuild.
class EditorHost extends StatelessComponent {
  const EditorHost({
    required this.tabs,
    required this.editorHostViewModel,
    required this.fileTree,
    required this.bootstrapLabel,
    super.key,
  });

  /// The tabs view model providing open tabs, active file, and error state.
  final TabsViewModel tabs;

  /// The view model providing diagnostics and problems-panel state.
  final EditorHostViewModel editorHostViewModel;

  /// The workspace file tree component.
  final Component fileTree;

  /// Human-readable label for the current bootstrap status.
  final String bootstrapLabel;

  @override
  Component build(BuildContext context) {
    return ListenableBuilder(
      listenable: tabs,
      builder: (context) => EditorShell(
        openTabs: tabs.openTabs,
        activeFile: tabs.activeFile,
        errorMessage: tabs.errorMessage,
        warningMessage: tabs.warningMessage,
        fileTree: fileTree,
        onSwitchFile: tabs.switchFile,
        onCloseFile: tabs.closeFile,
        bootstrapLabel: bootstrapLabel,
        bottomPanel: ListenableBuilder(
          listenable: editorHostViewModel,
          builder: (context) => BottomPanel(
            diagnostics: editorHostViewModel.diagnostics,
            activeFile: tabs.activeFile,
            showProblems: editorHostViewModel.showProblems,
            onShowProblems: editorHostViewModel.showProblemsPanel,
            onOpenDiagnostic: (fileName, diagnostic) {
              unawaited(
                editorHostViewModel.openDiagnostic(fileName, diagnostic),
              );
            },
          ),
        ),
      ),
    );
  }
}
