// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;

import '../lsp/diagnostic.dart';
import '../workspace/workspace_controller.dart';
import 'codemirror_editor.dart';

/// A controller that manages requesting, displaying, and applying
/// code actions (such as quick fixes and refactorings) for a specific file within a [CodeMirrorEditor].
class CodeActionsController {
  CodeActionsController({
    required this.codeEditor,
    required this.file,
    required this.workspaceController,
    required this.getDiagnostics,
    required this.onStateChanged,
  });

  final CodeMirrorEditor codeEditor;
  String file;
  final WorkspaceController workspaceController;
  final List<DiagnosticEntry> Function() getDiagnostics;
  final void Function() onStateChanged;

  bool showFloatingPanel = false;
  double panelLeft = 0;
  double panelTop = 0;
  List<cm.LSPCodeAction>? codeActions;

  /// Requests the available code actions from the LSP server at the current cursor selection
  /// and displays them in the floating panel.
  ///
  /// It filters diagnostics to find those overlapping with the selection and sends them as context.
  Future<void> triggerCodeActions() async {
    CodeMirrorEditor.hideAllTooltips();
    final plugin = cm.LSPPlugin.get(codeEditor.view);
    if (plugin == null) {
      return;
    }

    plugin.client.sync();

    final selection = codeEditor.view.state.selection.main;
    final startPos = plugin.toPosition(selection.from);
    final endPos = plugin.toPosition(selection.to);

    final fileDiagnostics = getDiagnostics()
        .where((entry) => entry.fileName == file)
        .map((entry) => entry.diagnostic)
        .toList();

    final overlappingDiagnostics = <dynamic>[];
    for (final diag in fileDiagnostics) {
      final rawRange = diag.raw?['range'] as Map?;
      if (rawRange != null) {
        final start = rawRange['start'] as Map?;
        final end = rawRange['end'] as Map?;
        if (start != null && end != null) {
          final startOffset = plugin.fromPosition(start.jsify() as JSObject);
          final endOffset = plugin.fromPosition(end.jsify() as JSObject);
          final intersects = startOffset <= selection.to && endOffset >= selection.from;
          if (intersects && diag.raw != null) {
            overlappingDiagnostics.add(diag.raw);
          }
        }
      }
    }

    final params = {
      'textDocument': {'uri': plugin.uri.toDart},
      'range': {'start': startPos, 'end': endPos},
      'context': {'diagnostics': overlappingDiagnostics},
    };

    final rect = codeEditor.view.coordsAtPos(selection.from);
    panelLeft = rect?.left ?? 100;
    panelTop = rect?.bottom ?? 100;

    try {
      final promise = plugin.client.request('textDocument/codeAction'.toJS, params.jsify() as JSObject);
      final result = await promise.toDart;
      if (result == null) {
        codeActions = [];
      } else {
        final arr = result as JSArray<JSObject>;
        codeActions = arr.toDart.map(cm.LSPCodeAction.new).toList();
      }

      showFloatingPanel = true;
      onStateChanged();
    } catch (e) {
      print('Error fetching code actions: $e');
    }
  }

  /// Applies the selected LSP code action, which may include workspace edits or commands, and hides the panel.
  Future<void> applyCodeAction(cm.LSPCodeAction action) async {
    final edit = action.edit;
    if (edit != null) {
      final Map<String, dynamic> editMap = (edit.dartify() as Map).cast<String, dynamic>();
      await workspaceController.languageServerClient.applyWorkspaceEdit(editMap);
    }

    final command = action.command;
    if (command != null) {
      final Map<String, dynamic> commandMap = (command.dartify() as Map).cast<String, dynamic>();
      final commandStr = commandMap['command'] as String;
      final arguments = commandMap['arguments'] as List<dynamic>?;
      await workspaceController.languageServerClient.executeCommand(commandStr, arguments);
    }

    hideCodeActionPanel();
    codeEditor.focus();
  }

  /// Hides the floating code action panel and clears the current code actions list.
  void hideCodeActionPanel() {
    showFloatingPanel = false;
    codeActions = null;
    onStateChanged();
  }
}
