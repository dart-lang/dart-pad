// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart' show kDebugMode;

import '../bottom_panel/view_models/console_view_model.dart';
import '../bottom_panel/view_models/diagnostics_view_model.dart';
import '../editor/codemirror/code_mirror_tab_adapter.dart';
import '../editor/image/image_tab.dart';
import '../editor/models/tab_descriptor.dart';
import '../editor/view_models/tabs_view_model.dart';
import '../filetree/file_tree_tabs_adapter.dart';
import '../filetree/file_tree_view_model.dart';
import '../preview/models/run_mode.dart';
import '../preview/view_models/preview_view_model.dart';
import '../shared/analyzer_status.dart';
import '../shared/app_event_bus.dart';
import '../shared/components/context_menu.dart';
import '../shared/task_status.dart';
import '../startup/initial_project_state.dart';
import 'data/workspace_repository.dart';

/// Owns every resource whose lifetime is tied to one worker workspace.
final class WorkspaceSession {
  WorkspaceSession._({
    required this.initialProject,
    required this.events,
    required this.taskStatus,
    required this.analyzerStatus,
    required this.repository,
    required this.console,
    required this.tabs,
    required this.fileTree,
    required this.diagnostics,
    required this.preview,
    required this.contextMenu,
    required this._codemirrorAdapter,
  });

  /// Creates runtime state from [initialProject]. A null [entrypoint] uses the
  /// snapshot's entrypoint; if both are null, Run starts disabled. An empty
  /// string is not a sentinel for clearing the entrypoint.
  /// [initialMode] must be resolved for the repository's SDK and the entrypoint
  /// before creating the session, including when switching SDKs.
  factory WorkspaceSession.create(
    WorkspaceRepository repository, {
    required InitialProjectState initialProject,
    required RunMode initialMode,
    String? entrypoint,
  }) {
    final contextMenu = ContextMenuController();
    late final WorkspaceSession session;
    final codemirrorAdapter = CodeMirrorTabAdapter(
      contextMenu: contextMenu,
      events: repository.events,
      onRun: () => session.runOrHotReload(),
      readSystemFile: repository.readSystemFile,
    );
    final tabs = TabsViewModel(
      workspaceResourceApi: repository.workspaceResourceApi,
      adapters: [
        ImageTabAdapter(
          workspaceResourceApi: repository.workspaceResourceApi,
        ),
        codemirrorAdapter,
      ],
    );
    final fileTree = FileTreeViewModel(
      tabs: FileTreeTabsAdapter(tabs),
      workspace: repository.workspaceResourceApi,
      rootPath: initialProject.root,
    );

    session = WorkspaceSession._(
      initialProject: initialProject,
      events: repository.events,
      taskStatus: repository.taskStatus,
      analyzerStatus: AnalyzerStatusController(repository.taskStatus),
      repository: repository,
      console: ConsoleViewModel(events: repository.events),
      tabs: tabs,
      fileTree: fileTree,
      diagnostics: DiagnosticsViewModel(tabs: tabs),
      preview: PreviewViewModel(
        workspaceRepository: repository,
        initialEntrypoint: entrypoint ?? initialProject.entrypoint,
        modeOverride: initialProject.request.mode,
        initialMode: initialMode,
        eventBus: repository.events,
        onSaveAll: tabs.saveAllTabs,
      ),
      contextMenu: contextMenu,
      codemirrorAdapter: codemirrorAdapter,
    );
    return session;
  }

  final InitialProjectState initialProject;
  final AppEventBus events;
  final TaskStatusController taskStatus;
  final AnalyzerStatusController analyzerStatus;
  final WorkspaceRepository repository;
  final ConsoleViewModel console;
  final TabsViewModel tabs;
  final FileTreeViewModel fileTree;
  final DiagnosticsViewModel diagnostics;
  final PreviewViewModel preview;
  final ContextMenuController contextMenu;
  final CodeMirrorTabAdapter _codemirrorAdapter;

  /// Triggers a hot reload if the preview is running, or runs the selected entrypoint
  /// if the preview is ready to start.
  void runOrHotReload() {
    if (preview.canHotReload) {
      unawaited(preview.hotReloadCode());
    } else if (preview.canStart) {
      unawaited(preview.runCurrent());
    }
  }

  /// Values only: these remain usable after the old tab objects are disposed.
  List<TabDescriptor> get tabSnapshot => List.unmodifiable([
    for (final tab in tabs.openTabs) TabDescriptor(path: tab.path, origin: tab.origin),
  ]);

  /// Opens [restoredTabs], or the snapshot's initial tabs when it is null.
  /// An empty list deliberately restores no tabs. A null or unmatched
  /// [activeFile] selects the first restored tab, when one exists.
  Future<void> openProjectFiles({
    List<TabDescriptor>? restoredTabs,
    String? activeFile,
  }) async {
    fileTree.focusPath(initialProject.root);
    final entries =
        restoredTabs ??
        [
          for (final path in initialProject.files) TabDescriptor(path: path, origin: EditorTabOrigin.workspace),
        ];
    for (final entry in entries) {
      if (_disposed) {
        return;
      }
      if (entry.origin == EditorTabOrigin.workspace) {
        await tabs.openWorkspaceFile(entry.path);
      } else {
        await tabs.openSystemFile(Uri.parse(entry.path));
      }
    }
    if (!_disposed && entries.isNotEmpty) {
      final selected = entries.any((entry) => entry.path == activeFile) ? activeFile! : entries.first.path;
      tabs.switchFile(selected);
    }
  }

  LanguageServer? _languageServer;
  LanguageServerClient? _languageServerClient;
  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;
  bool _disposed = false;

  /// Attaches language-server resources to this session's consumers.
  void attachLanguageServer({
    required LanguageServer server,
    required LanguageServerClient client,
    String? projectRoot,
  }) {
    if (_disposed) {
      throw StateError('Cannot attach a language server to a disposed session.');
    }
    if (_languageServer != null || _languageServerClient != null) {
      throw StateError('A language server is already attached to this session.');
    }

    _languageServer = server;
    _languageServerClient = client;
    _analyzerSubscription = client.analyzerActivityStream.listen(
      _onAnalyzerActivity,
      onError: (_) => analyzerStatus.markUnavailable(),
    );
    fileTree.languageServerClient = client;
    diagnostics.attachLanguageServer(client, projectRoot: projectRoot);
    _codemirrorAdapter.attachLanguageServerClient(client);
  }

  void _onAnalyzerActivity(AnalyzerActivity activity) {
    if (_disposed || activity is! AnalyzerStatusActivity) {
      return;
    }
    analyzerStatus.update(isAnalyzing: activity.isAnalyzing);
  }

  /// Disposes the complete workspace session at most once.
  Future<void> dispose({required bool closeWorker}) async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _safeAwait(_analyzerSubscription?.cancel());
    _analyzerSubscription = null;
    await _safeCall(diagnostics.dispose);
    await _safeCall(fileTree.dispose);
    await _safeCall(tabs.dispose);
    await _safeCall(preview.dispose);
    await _safeAwait(preview.closed);
    await _safeCall(console.dispose);
    await _safeAwait(
      _languageServerClient?.shutdown().timeout(
        const Duration(seconds: 2),
      ),
    );
    await _safeAwait(_languageServerClient?.dispose());
    _languageServerClient = null;
    await _safeAwait(_languageServer?.stop());
    _languageServer = null;

    contextMenu.hide();
    contextMenu.dispose();
    await _safeAwait(
      closeWorker ? repository.close() : repository.closeWorkspaceOnly(),
    );
    await _safeAwait(events.dispose());
    analyzerStatus.dispose();
    taskStatus.dispose();
  }

  /// Awaits a (possibly null) [future] and swallows errors so that a
  /// discarded session never affects its replacement.
  Future<void> _safeAwait(FutureOr<void>? future) async {
    try {
      await future;
    } catch (e) {
      if (kDebugMode) {
        print('WorkspaceSession cleanup error: $e');
      }
    }
  }

  /// Calls [fn] and swallows errors. Use this for tear-offs of methods
  /// that return `void` (which cannot be passed to [_safeAwait]).
  Future<void> _safeCall(FutureOr<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (kDebugMode) {
        print('WorkspaceSession cleanup error: $e');
      }
    }
  }
}
