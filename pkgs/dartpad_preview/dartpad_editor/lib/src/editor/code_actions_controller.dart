// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;

import '../lsp/diagnostic.dart';
import 'codemirror_editor.dart';

/// A controller that manages requesting, displaying, and applying
/// code actions (such as quick fixes and refactorings) for a specific file within a [CodeMirrorEditor].
class CodeActionsController {
  CodeActionsController({
    required this.codeEditor,
    required this.file,
    required this.getDiagnostics,
    required this.onStateChanged,
  });

  final CodeMirrorEditor codeEditor;
  String file;
  final List<DiagnosticEntry> Function() getDiagnostics;
  final void Function() onStateChanged;

  bool showFloatingPanel = false;
  double panelLeft = 0;
  double panelTop = 0;
  double anchorTop = 0;
  double anchorBottom = 0;
  List<cm.LSPCodeAction>? codeActions;
  int _requestSerial = 0;
  int _loadSerial = 0;
  bool _disposed = false;
  final _quickFixCache = _ActionsCacheSlot();
  final _allActionsCache = _ActionsCacheSlot();

  /// Returns whether the LSP currently offers a quick fix for the specified
  /// range.
  ///
  /// The result is cached for the matching document and range so activating the
  /// visible action does not issue the same request again.
  ///
  /// - [from]: The 0-based character offset at the start of the range in the
  ///   document.
  /// - [to]: The 0-based character offset at the end of the range in the
  ///   document.
  Future<bool> hasQuickFixes({required int from, required int to}) async {
    if (_disposed) {
      return false;
    }
    final plugin = cm.LSPPlugin.get(codeEditor.view);
    if (plugin == null) {
      return false;
    }
    final rangeFrom = from.clamp(0, codeEditor.view.state.doc.length);
    final rangeTo = to.clamp(rangeFrom, codeEditor.view.state.doc.length);
    try {
      final actions = await _loadActions(
        plugin,
        rangeFrom,
        rangeTo,
        only: const ['quickfix'],
        kindFilter: _quickFixKindFilter,
        cache: _quickFixCache,
      );
      return actions.isNotEmpty;
    } catch (e) {
      print('Error checking code actions: $e');
      return false;
    }
  }

  /// Requests quick fixes from the LSP server for the specified range, or for
  /// the current editor selection when no explicit range is provided.
  ///
  /// A single result is applied immediately. Multiple results are displayed in
  /// the floating panel so the user can choose one.
  ///
  /// - [from]: The optional 0-based character offset at the start of the range
  ///   in the document.
  /// - [to]: The optional 0-based character offset at the end of the range in
  ///   the document.
  Future<void> triggerQuickFixes({int? from, int? to}) => _triggerActions(
    from: from,
    to: to,
    autoApplySingle: true,
    loader: (plugin, rangeFrom, rangeTo) => _loadActions(
      plugin,
      rangeFrom,
      rangeTo,
      only: const ['quickfix'],
      kindFilter: _quickFixKindFilter,
      cache: _quickFixCache,
    ),
  );

  /// Requests all code actions (quick fixes, refactorings, source actions, etc.)
  /// from the LSP server for the current editor selection.
  ///
  /// Unlike [triggerQuickFixes], this does not filter by kind and is intended
  /// for the Cmd/Ctrl+. shortcut.
  Future<void> triggerCodeActions() => _triggerActions(
    loader: (plugin, rangeFrom, rangeTo) => _loadActions(
      plugin,
      rangeFrom,
      rangeTo,
      cache: _allActionsCache,
    ),
  );

  Future<void> _triggerActions({
    int? from,
    int? to,
    bool autoApplySingle = false,
    required Future<List<cm.LSPCodeAction>> Function(cm.LSPPlugin, int, int) loader,
  }) async {
    if (_disposed) {
      return;
    }
    final requestSerial = ++_requestSerial;
    CodeMirrorEditor.hideAllTooltips();
    final plugin = cm.LSPPlugin.get(codeEditor.view);
    if (plugin == null) {
      return;
    }

    final selection = codeEditor.view.state.selection.main;
    final rangeFrom = (from ?? selection.from).clamp(0, codeEditor.view.state.doc.length);
    final rangeTo = (to ?? selection.to).clamp(rangeFrom, codeEditor.view.state.doc.length);

    final rect = codeEditor.view.coordsAtPos(rangeFrom);
    panelLeft = rect?.left ?? 100;
    panelTop = rect?.bottom ?? 100;
    anchorTop = rect?.top ?? 100;
    anchorBottom = rect?.bottom ?? 100;
    showFloatingPanel = true;
    codeActions = null;
    onStateChanged();

    try {
      final actions = await loader(plugin, rangeFrom, rangeTo);
      if (_disposed || requestSerial != _requestSerial) {
        return;
      }

      if (autoApplySingle && actions.length == 1) {
        await applyCodeAction(actions.single);
        return;
      }
      codeActions = actions;
      showFloatingPanel = true;
      onStateChanged();
    } catch (e) {
      if (_disposed || requestSerial != _requestSerial) {
        return;
      }
      codeActions = [];
      showFloatingPanel = true;
      onStateChanged();
      print('Error fetching code actions: $e');
    }
  }

  Future<List<cm.LSPCodeAction>> _loadActions(
    cm.LSPPlugin plugin,
    int from,
    int to, {
    List<String>? only,
    bool Function(cm.LSPCodeAction)? kindFilter,
    required _ActionsCacheSlot cache,
  }) async {
    final document = codeEditor.view.state.doc;
    if (identical(document, cache.document) && from == cache.from && to == cache.to) {
      return cache.actions!;
    }

    plugin.client.sync();
    final loadSerial = ++_loadSerial;
    final overlappingDiagnostics = <Object?>[];
    for (final diagnostic
        in getDiagnostics().where((entry) => entry.fileName == file).map((entry) => entry.diagnostic)) {
      final rawRange = diagnostic.raw?['range'] as Map?;
      final start = rawRange?['start'] as Map?;
      final end = rawRange?['end'] as Map?;
      if (start == null || end == null) {
        continue;
      }
      final startOffset = plugin.fromPosition(start.jsify() as JSObject);
      final endOffset = plugin.fromPosition(end.jsify() as JSObject);
      if (startOffset <= to && endOffset >= from && diagnostic.raw != null) {
        overlappingDiagnostics.add(diagnostic.raw);
      }
    }

    final context = <String, Object?>{
      'diagnostics': overlappingDiagnostics,
      'triggerKind': 1,
    };
    if (only != null) {
      context['only'] = only;
    }
    final params = {
      'textDocument': {'uri': plugin.uri.toDart},
      'range': {
        'start': plugin.toPosition(from),
        'end': plugin.toPosition(to),
      },
      'context': context,
    };
    final result = await plugin.client.request('textDocument/codeAction'.toJS, params.jsify() as JSObject).toDart;
    if (_disposed || !identical(document, codeEditor.view.state.doc)) {
      return [];
    }
    final actions = <cm.LSPCodeAction>[];
    if (result != null) {
      final array = result as JSArray<JSObject>;
      final mapped = array.toDart.map(cm.LSPCodeAction.new);
      actions.addAll(kindFilter != null ? mapped.where(kindFilter) : mapped);
    }

    if (loadSerial == _loadSerial) {
      cache.document = document;
      cache.from = from;
      cache.to = to;
      cache.actions = actions;
    }
    return actions;
  }

  static bool _quickFixKindFilter(cm.LSPCodeAction action) {
    final kind = action.kind?.toDart;
    return kind == null || kind.startsWith('quickfix');
  }

  /// Applies the selected LSP code action, which may include workspace edits or commands, and hides the panel.
  Future<void> applyCodeAction(cm.LSPCodeAction action) async {
    if (_disposed) {
      return;
    }
    final edit = action.edit;
    if (edit != null) {
      final editMap = (edit.dartify() as Map).cast<String, Object?>();
      await codeEditor.languageServerClient?.applyWorkspaceEdit(editMap);
    }

    final command = action.command;
    if (command != null) {
      final commandMap = (command.dartify() as Map).cast<String, Object?>();
      final commandStr = commandMap['command'] as String;
      final arguments = commandMap['arguments'] as List<Object?>?;
      await codeEditor.languageServerClient?.executeCommand(commandStr, arguments);
    }

    _clearCache();

    hideCodeActionPanel();
    codeEditor.focus();
  }

  /// Hides the floating code action panel and clears the current code actions list.
  void hideCodeActionPanel() {
    if (_disposed) {
      return;
    }
    _requestSerial++;
    showFloatingPanel = false;
    codeActions = null;
    onStateChanged();
  }

  /// Cancels pending UI updates when the owning editor tab is destroyed.
  void dispose() {
    _disposed = true;
    _requestSerial++;
    _loadSerial++;
    showFloatingPanel = false;
    codeActions = null;
    _clearCache();
  }

  void _clearCache() {
    _loadSerial++;
    _quickFixCache.clear();
    _allActionsCache.clear();
  }
}

/// Holds the cached result of a single code-action LSP request.
class _ActionsCacheSlot {
  cm.Text? document;
  int? from;
  int? to;
  List<cm.LSPCodeAction>? actions;

  void clear() {
    document = null;
    from = null;
    to = null;
    actions = null;
  }
}
