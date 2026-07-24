// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../shared/node_container.dart';

/// A workspace-backed text editor tab that preserves its editor state while
/// switching between files.
final class CodeMirrorTab extends EditorTab<Component> {
  /// Creates a tab for [path] with the given initial [content].
  CodeMirrorTab({
    required String path,
    required String content,
    required this.onSaveAll,
    required this.workspaceResourceApi,
    LanguageServerClient? languageServerClient,
  }) : _savedContent = content,
       container = web.document.createElement('div') as web.HTMLElement,
       super(path) {
    container.className = 'editor-container';
    editor = CodeMirrorEditor(
      container,
      file: path,
      initialDoc: content,
      onUpdate: _handleEditorUpdate,
      onSave: onSaveAll,
      languageServerClient: languageServerClient,
    );
  }

  /// Saves all dirty tabs when CodeMirror receives its save command.
  final void Function() onSaveAll;

  final WorkspaceResourceApi workspaceResourceApi;

  /// The DOM element that hosts the CodeMirror editor.
  final web.HTMLElement container;

  /// The CodeMirror editor managed by this tab.
  late final CodeMirrorEditor editor;

  final StreamController<void> _updates = StreamController<void>.broadcast();
  EditorViewState? _savedViewState;
  late String _savedContent;
  bool _isDirty = false;
  bool _active = false;
  bool _disposed = false;
  Timer? _measureTimer;

  /// The current editor content.
  String get content => editor.text;

  @override
  bool get keepAlive => true;

  @override
  bool get hasUnsavedChanges => _isDirty;

  @override
  Stream<void> get onUpdate => _updates.stream;

  @override
  void onActivate() {
    _active = true;
    _scheduleMeasureAndRestore();
  }

  @override
  void onDeactivate() {
    _active = false;
    _measureTimer?.cancel();
    _measureTimer = null;
    _savedViewState = editor.saveViewState();
  }

  void _scheduleMeasureAndRestore() {
    _measureTimer?.cancel();
    _measureTimer = Timer(Duration.zero, () {
      _measureTimer = null;
      if (_disposed || !_active || !container.isConnected) {
        return;
      }
      editor.requestMeasure();
      final savedViewState = _savedViewState;
      if (savedViewState != null) {
        editor.restoreViewState(savedViewState);
      }
      editor.triggerLspRefresh();
    });
  }

  @override
  Future<void> save() async {
    if (!_isDirty) {
      return;
    }
    if (path.endsWith('.dart')) {
      final formatted = await editor.format();
      if (!formatted) {
        throw StateError('Formatting failed; $path was not saved.');
      }
    }

    await _persistCurrentContent();
  }

  Future<void> _persistCurrentContent() async {
    final content = editor.text;
    await workspaceResourceApi.root.getFile(path).writeContent(content);
    _savedContent = content;
    _isDirty = false;
    _notifyUpdate();
  }

  @override
  void discardUnsavedChanges() {
    if (!_isDirty) {
      return;
    }
    editor.text = _savedContent;
    _isDirty = false;
    _notifyUpdate();
  }

  /// Applies LSP edits and persists them when the document was previously
  /// clean. Dirty documents keep the combined user and LSP edits in memory.
  Future<void> applyEdits(List<dynamic> edits) async {
    final wasDirty = _isDirty;
    editor.applyEdits(edits);
    if (!wasDirty) {
      await _persistCurrentContent();
    } else {
      _notifyUpdate();
    }
  }

  @override
  void rename(String newPath) {
    super.rename(newPath);
    editor.applyRename(newPath);
  }

  void _handleEditorUpdate(String content) {
    _isDirty = content != _savedContent;
    _notifyUpdate();
  }

  void _notifyUpdate() {
    if (!_disposed) {
      _updates.add(null);
    }
  }

  @override
  Component build() => NodeContainer(
    container,
    onAttached: _scheduleMeasureAndRestore,
  );

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _active = false;
    _measureTimer?.cancel();
    _measureTimer = null;
    editor.destroy();
    unawaited(_updates.close());
  }
}
