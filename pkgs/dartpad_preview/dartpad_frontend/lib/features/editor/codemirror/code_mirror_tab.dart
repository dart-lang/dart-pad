// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/node_container.dart';
import '../components/code_action_panel.dart';
import 'editor_context_menu.dart';

/// A workspace-backed text editor tab that preserves its editor state while
/// switching between files.
final class CodeMirrorTab extends EditorTab<Component> {
  /// Creates a tab for [path] with the given initial [content].
  CodeMirrorTab({
    required String path,
    required String content,
    required this.onSaveAll,
    required this.workspaceResourceApi,
    this.contextMenu,
    this.events,
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
      onCodeActionRequested: () {
        unawaited(codeActionsController.triggerCodeActions());
      },
      onQuickFixRequested: (from, to) {
        unawaited(codeActionsController.triggerQuickFixes(from: from, to: to));
      },
      onQuickFixAvailabilityRequested: (from, to) {
        return codeActionsController.hasQuickFixes(from: from, to: to);
      },
      languageServerClient: languageServerClient,
    );
    codeActionsController = CodeActionsController(
      codeEditor: editor,
      file: path,
      getDiagnostics: () => editor.languageServerClient?.allDiagnostics ?? const [],
      onStateChanged: _notifyUpdate,
    );

    _contextMenuHandler = (web.MouseEvent event) {
      event.preventDefault();
      event.stopPropagation();
      _showContextMenu(event.clientX.toDouble(), event.clientY.toDouble());
    }.toJS;
    container.addEventListener('contextmenu', _contextMenuHandler);
  }

  late final JSFunction _contextMenuHandler;

  /// Saves all dirty tabs when CodeMirror receives its save command.
  final void Function() onSaveAll;

  final WorkspaceResourceApi workspaceResourceApi;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  /// The event bus for system notifications and error toasts.
  final AppEventBus? events;

  /// The DOM element that hosts the CodeMirror editor.
  final web.HTMLElement container;

  /// The CodeMirror editor managed by this tab.
  late final CodeMirrorEditor editor;

  /// Coordinates LSP quick-fix requests and the optional action chooser.
  late final CodeActionsController codeActionsController;

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

  /// Moves the cursor to [line] and [character] and keeps that position when
  /// this tab has just been activated.
  void goToPosition(int line, int character) {
    // Activating a previously opened tab schedules its saved view state to be
    // restored on the next event-loop turn. A deliberate navigation request
    // supersedes that state and must not be overwritten by the pending restore.
    _savedViewState = null;
    editor.goToPosition(line, character);
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

  /// Applies LSP edits in memory. The editor update listener marks the tab as
  /// dirty, and the changes are persisted through the normal save flow.
  Future<void> applyEdits(List<dynamic> edits) async {
    editor.applyEdits(edits);
  }

  @override
  void rename(String newPath) {
    super.rename(newPath);
    codeActionsController.file = newPath;
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

  void _showContextMenu(double clientX, double clientY) {
    final menu = contextMenu;
    if (menu == null) {
      return;
    }

    final pos = editor.view.posAtCoords(cm.EditorCoords(x: clientX, y: clientY));
    if (pos != null) {
      final selection = editor.view.state.selection;
      final insideSelection = selection.ranges.toDart.any((r) => pos >= r.from && pos <= r.to);
      if (!insideSelection) {
        editor.view.dispatch(cm.TransactionSpec(selection: cm.EditorSelection.single(pos)));
      }
    }

    menu.show(
      clientX,
      clientY,
      buildEditorContextMenu(
        editor: editor,
        path: path,
        events: events,
      ),
    );
  }

  @override
  Component build() => Component.fragment([
    NodeContainer(
      container,
      onAttached: _scheduleMeasureAndRestore,
    ),
    if (codeActionsController.showFloatingPanel) CodeActionPanel(controller: codeActionsController),
  ]);

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _active = false;
    _measureTimer?.cancel();
    _measureTimer = null;
    container.removeEventListener('contextmenu', _contextMenuHandler);
    codeActionsController.dispose();
    editor.destroy();
    unawaited(_updates.close());
  }
}
