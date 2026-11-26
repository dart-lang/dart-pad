// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:codemirror_dart/codemirror_dart.dart' as cm;
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../shared/components/context_menu.dart';
import '../../shared/node_container.dart';
import '../components/code_action_panel.dart';
import 'editor_context_menu.dart';

/// Shared editor display, navigation, and lifecycle for CodeMirror tabs.
sealed class CodeMirrorTab extends EditorTab<Component> {
  CodeMirrorTab._(super.path, EditorTabOrigin origin)
    : container = web.document.createElement('div') as web.HTMLElement,
      super(origin: origin) {
    container.className = 'editor-container';
  }

  /// The DOM element that hosts the CodeMirror editor.
  final web.HTMLElement container;

  /// The CodeMirror editor managed by this tab.
  late final CodeMirrorEditor editor;

  /// Whether the editor is attached and displayed in the document.
  bool get _isEditorDisplayed => container.isConnected && container.getClientRects().length > 0;

  EditorViewState? _savedViewState;
  bool _active = false;
  bool _disposed = false;
  Timer? _measureTimer;
  final StreamController<void> _updates = StreamController<void>.broadcast();
  @override
  Stream<void> get onUpdate => _updates.stream;

  void _notifyUpdate() {
    if (!_disposed) {
      _updates.add(null);
    }
  }

  /// The current editor content.
  String get content => editor.text;

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
    // A detached or hidden editor has no layout state worth saving.
    if (_isEditorDisplayed) {
      _savedViewState = editor.saveViewState();
    }
  }

  void _scheduleMeasureAndRestore() {
    _measureTimer?.cancel();
    _measureTimer = Timer(Duration.zero, () {
      _measureTimer = null;
      if (_disposed || !_active || !_isEditorDisplayed) {
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
  Component build() => NodeContainer(container, onAttached: _scheduleMeasureAndRestore);

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

/// The presentation shown by an editable workspace tab.
enum PresentationMode { source, presentation }

/// An editable workspace text tab with autosave, code actions, and a context menu.
final class WorkspaceCodeMirrorTab extends CodeMirrorTab with _WorkspaceMarkdownPreview {
  /// Creates an editable tab for the workspace-relative [path].
  WorkspaceCodeMirrorTab({
    required String path,
    required String content,
    required this.onSaveAll,
    required this.workspaceResourceApi,
    void Function()? onRun,
    this.contextMenu,
    this.analyzerEnabled = true,
    this.events,
    LanguageServerClient? languageServerClient,
  }) : _savedContent = content,
       super._(path, EditorTabOrigin.workspace) {
    editor = CodeMirrorEditor(
      container,
      filePath: path,
      initialDoc: content,
      onUpdate: _handleEditorUpdate,
      onSave: onSaveAll,
      onRun: onRun,
      onBlur: _handleBlur,
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
      readOnly: origin.isReadOnly,
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
    _initializeMarkdownView();
  }

  /// Saves all dirty tabs when CodeMirror receives its save command.
  final void Function() onSaveAll;

  /// Provides access to the editable project files.
  final WorkspaceResourceApi workspaceResourceApi;

  /// The context menu controller used to show right-click menus.
  final ContextMenuController? contextMenu;

  /// Whether analyzer support is enabled by the app's startup policy.
  final bool analyzerEnabled;

  /// The event bus for system notifications and error toasts.
  final AppEventBus? events;

  /// Coordinates LSP quick-fix requests and the optional action chooser.
  late final CodeActionsController codeActionsController;

  late final JSFunction _contextMenuHandler;
  String _savedContent;
  bool _isDirty = false;
  PresentationMode _presentationMode = PresentationMode.source;

  /// The current presentation, with the editor retained in both modes.
  @override
  PresentationMode get presentationMode => _presentationMode;

  /// Updates the presentation after saving the source view and before scheduling
  /// its restoration. [updateView] must run synchronously without reentering.
  @override
  void _updateEditorPresentation({
    required PresentationMode presentationMode,
    required void Function() updateView,
  }) {
    if (_disposed) {
      return;
    }

    final previousMode = _presentationMode;
    if (previousMode == PresentationMode.source && presentationMode == PresentationMode.presentation) {
      if (_active && _isEditorDisplayed) {
        _savedViewState = editor.saveViewState();
        CodeMirrorEditor.hideAllTooltips();
      }
      _measureTimer?.cancel();
      _measureTimer = null;
    }

    updateView();
    _presentationMode = presentationMode;

    if (previousMode == PresentationMode.presentation && presentationMode == PresentationMode.source) {
      _scheduleMeasureAndRestore();
    }
    _notifyUpdate();
  }

  @override
  bool get keepAlive => true;

  @override
  bool get hasUnsavedChanges => _isDirty;

  @override
  void onDeactivate() {
    super.onDeactivate();
    if (_isDirty) {
      onSaveAll();
    }
  }

  void _handleBlur() {
    if (_isDirty) {
      onSaveAll();
    }
  }

  @override
  Future<void> save() async {
    if (!_isDirty) {
      return;
    }
    if (path.endsWith('.dart')) {
      try {
        await editor.format();
      } catch (_) {
        // Formatting is best-effort on save.
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
  Future<void> applyEdits(List<Object?> edits) async {
    editor.applyEdits(edits);
  }

  @override
  void rename(String newPath) {
    _updateEditorPresentation(
      presentationMode: _presentationModeForPath(newPath),
      updateView: () {
        super.rename(newPath);
        codeActionsController.file = newPath;
        editor.applyRename(newPath);
      },
    );
  }

  void _handleEditorUpdate(String content) {
    _isDirty = content != _savedContent;
    _notifyUpdate();
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
        analyzerEnabled: analyzerEnabled,
        events: events,
      ),
    );
  }

  @override
  Component build() => _buildMarkdownView(
    Component.fragment([
      super.build(),
      if (codeActionsController.showFloatingPanel) CodeActionPanel(controller: codeActionsController),
    ]),
  );

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    container.removeEventListener('contextmenu', _contextMenuHandler);
    codeActionsController.dispose();
    super.dispose();
  }
}

/// A read-only system source tab that is disposed when closed.
final class SystemCodeMirrorTab extends CodeMirrorTab {
  /// Creates a tab for [uri] without project write access.
  ///
  /// [onRun] runs or hot reloads the project on Cmd/Ctrl+Enter.
  SystemCodeMirrorTab({
    required Uri uri,
    required String content,
    void Function()? onRun,
    LanguageServerClient? languageServerClient,
  }) : super._(uri.toString(), EditorTabOrigin.system) {
    editor = CodeMirrorEditor(
      container,
      filePath: path,
      initialDoc: content,
      // Consume Mod-S so the browser does not open its Save page dialog.
      onSave: () {},
      onRun: onRun,
      languageServerClient: languageServerClient,
      readOnly: origin.isReadOnly,
    );
  }
}

/// Markdown rendering and mode selection for workspace tabs.
///
/// The workspace owns the presentation lifecycle; this mixin supplies the file
/// rules and rendering through initialization, build, and rename hooks.
mixin _WorkspaceMarkdownPreview on CodeMirrorTab {
  web.HTMLDivElement? _previewContainer;
  String? _renderedContent;
  late PresentationMode _preferredMode;

  PresentationMode get presentationMode;

  void _updateEditorPresentation({
    required PresentationMode presentationMode,
    required void Function() updateView,
  });

  void _initializeMarkdownView() {
    final initialMode = isMarkdown ? PresentationMode.presentation : PresentationMode.source;
    _updateEditorPresentation(
      presentationMode: initialMode,
      updateView: () => _preferredMode = initialMode,
    );
  }

  /// Whether the current path supports Markdown preview.
  bool get isMarkdown => isMarkdownFile(path);

  PresentationMode _presentationModeForPath(String filePath) =>
      isMarkdownFile(filePath) ? _preferredMode : PresentationMode.source;

  /// Switches Markdown display without recreating the editor.
  void setPresentationMode(PresentationMode mode) {
    if (!isMarkdown || presentationMode == mode) {
      return;
    }
    _updateEditorPresentation(
      presentationMode: mode,
      updateView: () => _preferredMode = mode,
    );
  }

  Component _buildMarkdownView(Component source) {
    // Keep stable wrappers so Jaspr does not reuse CodeMirror's externally
    // managed DOM container as one of its own elements.
    final previewContainer = isMarkdown
        ? (_previewContainer ??= web.HTMLDivElement()
            ..className = 'markdown-preview'
            ..setAttribute('role', 'document')
            ..setAttribute('aria-label', 'Markdown preview')
            ..tabIndex = 0)
        : null;
    final showPreview = presentationMode == PresentationMode.presentation;
    if (showPreview && _renderedContent != content) {
      previewContainer!.innerHTML = renderMarkdown(content).toJS;
      _renderedContent = content;
    }
    return div(classes: 'workspace-text-tab', [
      div(
        classes: 'workspace-source${isMarkdown ? ' markdown-source' : ''}',
        attributes: {if (showPreview) 'hidden': ''},
        [source],
      ),
      if (previewContainer != null)
        div(
          classes: 'markdown-rendered',
          attributes: {if (!showPreview) 'hidden': ''},
          [NodeContainer(previewContainer)],
        ),
    ]);
  }
}
