// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import 'features/bottom_panel/view_models/console_view_model.dart';
import 'features/bottom_panel/view_models/diagnostics_view_model.dart';
import 'features/bottom_panel/views/bottom_panel.dart';
import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/codemirror/code_mirror_tab_adapter.dart';
import 'features/editor/components/editor_shell.dart';
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/editor/image/image_tab.dart';
import 'features/editor/view_models/tabs_view_model.dart';
import 'features/filetree/file_tree_tabs_adapter.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/filetree/file_tree_view_model.dart';
import 'features/preview/view/preview_container.dart';
import 'features/preview/view_models/preview_view_model.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/app_bar.dart';
import 'features/shared/components/footer.dart';
import 'features/shared/components/split_panel.dart';
import 'features/shared/events/log_event.dart';
import 'features/startup/archive_loader.dart';
import 'features/startup/gist_loader.dart';
import 'features/startup/project_loader.dart';
import 'features/startup/sample_project.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/workspace_lifecycle.dart';

/// The deliberately small first production slice of DartPad.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();

  @css
  static List<StyleRule> get styles => AppState.styles;
}

/// Owns every resource whose lifetime is tied to one worker workspace.
final class _WorkspaceSession {
  _WorkspaceSession({
    required this.events,
    required this.repository,
    required this.console,
    required this.tabs,
    required this.fileTree,
    required this.diagnostics,
    required this.preview,
    required this.codemirrorAdapter,
  });

  final AppEventBus events;
  final WorkspaceRepository repository;
  final ConsoleViewModel console;
  final TabsViewModel tabs;
  final FileTreeViewModel fileTree;
  final DiagnosticsViewModel diagnostics;
  final PreviewViewModel preview;
  final CodeMirrorTabAdapter codemirrorAdapter;

  LanguageServer? languageServer;
  LanguageServerClient? languageServerClient;
  StreamSubscription<AnalyzerActivity>? analyzerSubscription;
  bool _disposed = false;

  Future<void> dispose({required bool closeWorker}) async {
    if (_disposed) {
      return;
    }
    _disposed = true;

    await _ignoreCleanupError(() async {
      await analyzerSubscription?.cancel();
    });
    analyzerSubscription = null;
    await _ignoreCleanupError(diagnostics.dispose);
    await _ignoreCleanupError(fileTree.dispose);
    await _ignoreCleanupError(tabs.dispose);
    await _ignoreCleanupError(preview.dispose);
    await _ignoreCleanupError(console.dispose);
    await _ignoreCleanupError(() async {
      await languageServerClient?.shutdown().timeout(
        const Duration(seconds: 2),
      );
    });
    await _ignoreCleanupError(() async {
      await languageServerClient?.dispose();
    });
    languageServerClient = null;
    await _ignoreCleanupError(() async {
      await languageServer?.stop();
    });
    languageServer = null;

    await _ignoreCleanupError(() async {
      if (closeWorker) {
        await repository.close();
      } else {
        await repository.closeWorkspaceOnly();
      }
    });
    await _ignoreCleanupError(() async {
      await events.dispose();
    });
  }

  Future<void> _ignoreCleanupError(FutureOr<void> Function() cleanup) async {
    try {
      await cleanup();
    } catch (_) {
      // A discarded session must never affect its replacement.
    }
  }
}

/// Composition root – wires all services and drives the startup lifecycle.
class AppState extends State<App> {
  late _WorkspaceSession _session;

  /// Incremented on every workspace reset. Used as a [ValueKey] so Jaspr
  /// unmounts the old workspace subtree (including CodeMirror NodeContainers)
  /// rather than trying to update them in-place.
  int _workspaceGeneration = 0;

  bool _isInitializingWorkspace = true;
  String loadingStatus = 'Loading Workspace...';
  String _projectDir = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final events = AppEventBus();
    _session = _createSession(
      WorkspaceRepository.create(events: events),
    );
    unawaited(_initializeWorkspace(_session));
  }

  _WorkspaceSession _createSession(WorkspaceRepository repository) {
    final codemirrorAdapter = CodeMirrorTabAdapter();
    final tabs = TabsViewModel(
      workspaceResourceApi: repository.workspaceResourceApi,
      adapters: [
        ImageTabAdapter(workspaceResourceApi: repository.workspaceResourceApi),
        codemirrorAdapter,
      ],
    );
    final fileTree = FileTreeViewModel(
      tabs: FileTreeTabsAdapter(tabs),
      workspace: repository.workspaceResourceApi,
    );

    return _WorkspaceSession(
      events: repository.events,
      repository: repository,
      console: ConsoleViewModel(events: repository.events),
      tabs: tabs,
      fileTree: fileTree,
      diagnostics: DiagnosticsViewModel(tabs: tabs),
      preview: PreviewViewModel(
        workspaceRepository: repository,
        eventBus: repository.events,
      ),
      codemirrorAdapter: codemirrorAdapter,
    );
  }

  bool _isCurrent(_WorkspaceSession session) => mounted && identical(_session, session);

  /// Loads the workspace and project. Once the initial file has been opened,
  /// the workspace is usable and another reset may be requested. Pub and LSP
  /// initialization deliberately continue in the background.
  Future<void> _initializeWorkspace(
    _WorkspaceSession session, {
    bool forceSample = false,
  }) async {
    final projectFuture = _loadProject(session, forceSample: forceSample);

    try {
      final (:workspace, :project) = await waitForWorkspaceUsable(
        workspaceReady: session.repository.readyWorkspace,
        projectReady: projectFuture,
      );
      if (!_isCurrent(session)) {
        return;
      }

      setState(() {
        _isInitializingWorkspace = false;
      });

      unawaited(_initializeWorkspaceTools(session, workspace, project));
    } catch (error) {
      if (!_isCurrent(session)) {
        return;
      }
      setState(() {
        _isInitializingWorkspace = false;
        _errorMessage = 'Failed to initialize workspace: $error';
      });
    }
  }

  Future<void> _initializeWorkspaceTools(
    _WorkspaceSession session,
    Workspace workspace,
    LoadedProject? project,
  ) async {
    try {
      if (project?.packageRoot case final String packageRoot) {
        if (!_isCurrent(session)) {
          return;
        }
        setState(() {
          loadingStatus = 'Running Pub Get...';
        });

        try {
          await session.repository.pubGet(
            path: packageRoot,
            projectRoot: packageRoot,
          );
        } catch (error, stackTrace) {
          if (_isCurrent(session)) {
            session.events.dispatch(
              LogEvent(
                'Pub get failed.',
                level: Level.SEVERE,
                error: error,
                stackTrace: stackTrace,
              ),
            );
          }
        }
      }

      if (!_isCurrent(session)) {
        return;
      }
      setState(() {
        loadingStatus = 'Initializing Analyzer...';
      });

      final languageServer = await workspace.startLanguageServer();
      if (!_isCurrent(session)) {
        await languageServer.stop();
        return;
      }

      final languageServerClient = LanguageServerClient(
        languageServer: languageServer,
        rootWorkspaceUri: workspace.workspaceFolder,
        workspaceChangeEvents: session.repository.workspaceResourceApi.changeEvents,
        documentEditsHandler: (filePath, edits) async {
          final tab = session.tabs.getTab(filePath);
          if (tab is CodeMirrorTab) {
            await tab.applyEdits(edits);
          } else {
            final file = session.repository.root.getFile(filePath);
            await file.writeContent(
              LanguageServerClient.applyEdits(await file.readContent(), edits),
            );
          }
        },
        displayFileHandler: session.tabs.openFile,
      );
      if (!_isCurrent(session)) {
        await languageServerClient.dispose();
        await languageServer.stop();
        return;
      }

      session.languageServer = languageServer;
      session.languageServerClient = languageServerClient;
      session.analyzerSubscription = languageServerClient.analyzerActivityStream.listen(
        (activity) => _updateAnalyzerStatus(session, activity),
      );
      session.fileTree.languageServerClient = languageServerClient;
      session.diagnostics.attachLanguageServer(languageServerClient);
      session.codemirrorAdapter.attachLanguageServerClient(languageServerClient);

      setState(() {
        loadingStatus = 'Analyzing Project...';
      });
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) {
        return;
      }
      session.events.dispatch(
        LogEvent(
          'Analyzer initialization failed.',
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      setState(() {
        loadingStatus = 'Analyzer initialization failed.';
      });
    }
  }

  /// Replaces the current workspace with a fresh sample workspace on the same
  /// worker. The old session is disposed only after Jaspr has unmounted its
  /// keyed subtree.
  void resetWorkspace() {
    final oldSession = _session;
    final worker = oldSession.repository.dartpad;
    if (_isInitializingWorkspace || worker == null) {
      return;
    }

    final previousWorkspaceDisposed = Completer<void>();
    final events = AppEventBus();
    final nextSession = _createSession(
      WorkspaceRepository.resetAndCreate(
        events: events,
        worker: worker,
        previousWorkspaceDisposed: previousWorkspaceDisposed.future,
      ),
    );

    if (web.window.location.search.isNotEmpty) {
      web.window.history.pushState(null, '', web.window.location.pathname);
    }

    setState(() {
      _workspaceGeneration++;
      _session = nextSession;
      _isInitializingWorkspace = true;
      loadingStatus = 'Initializing Workspace...';
      _errorMessage = null;
      _projectDir = '';
    });

    unawaited(_initializeWorkspace(nextSession, forceSample: true));
    disposeAfterWorkspaceUnmount(
      context,
      () async {
        try {
          await oldSession.dispose(closeWorker: false);
        } finally {
          previousWorkspaceDisposed.complete();
        }
      },
    );
  }

  Future<LoadedProject?> _loadProject(
    _WorkspaceSession session, {
    bool forceSample = false,
  }) async {
    final params = forceSample ? const <String, String>{} : Uri.base.queryParameters;

    try {
      final LoadedProject project;
      if (params case {
        'archive': final String archiveUrlParam,
        'path': final String filePathParam,
      }) {
        _updateLoadingStatus(session, 'Downloading Archive...', clearError: true);
        final archiveUrl = Uri.decodeComponent(archiveUrlParam);
        final filePath = Uri.decodeComponent(filePathParam);
        final loader = ArchiveLoader(archiveUrl: archiveUrl, filePath: filePath);
        project = await loader.loadArchive(session.repository.root);
      } else if (params case {'package': final String packageName}) {
        _updateLoadingStatus(session, 'Resolving Package...', clearError: true);
        final loader = await ArchiveLoader.forPackage(packageName);
        _updateLoadingStatus(session, 'Downloading Package...');
        project = await loader.loadArchive(session.repository.root);
      } else if (params['gist'] case final String gistId) {
        _updateLoadingStatus(session, 'Downloading Gist...', clearError: true);
        final loader = GistLoader(gistId: gistId);
        project = await loader.loadGist(session.repository.root);
      } else {
        _updateLoadingStatus(session, 'Initializing Workspace...', clearError: true);
        await createSampleProject(session.repository.root);
        project = const LoadedProject(
          projectDir: '',
          entryPath: sampleProjectEntryPath,
          packageRoot: '',
        );
      }

      if (!_isCurrent(session)) {
        return project;
      }

      setState(() {
        _projectDir = project.projectDir;
      });
      session.fileTree.focusPath(project.projectDir);
      if (project.entryPath case final String entryPath) {
        await session.tabs.openFile(entryPath);
      }

      return project;
    } catch (error) {
      if (_isCurrent(session)) {
        setState(() {
          _errorMessage = 'Failed to load project: $error';
        });
      }
      return null;
    }
  }

  void _updateLoadingStatus(
    _WorkspaceSession session,
    String status, {
    bool clearError = false,
  }) {
    if (!_isCurrent(session)) {
      return;
    }
    setState(() {
      loadingStatus = status;
      if (clearError) {
        _errorMessage = null;
      }
    });
  }

  void _updateAnalyzerStatus(
    _WorkspaceSession session,
    AnalyzerActivity activity,
  ) {
    if (!_isCurrent(session) || activity is! AnalyzerStatusActivity) {
      return;
    }

    final status = activity.isAnalyzing ? 'Analyzing Project...' : 'Done';
    if (loadingStatus == status) {
      return;
    }

    setState(() {
      loadingStatus = status;
    });
  }

  @override
  Component build(BuildContext context) {
    final session = _session;
    return div(classes: 'app-shell', [
      AppBar(
        onCreateNew: _isInitializingWorkspace || session.repository.dartpad == null ? null : resetWorkspace,
      ),
      ListenableBuilder(
        key: ValueKey(_workspaceGeneration),
        listenable: session.tabs,
        builder: (context) => div(classes: 'app-workspace-container', [
          div(classes: 'app-workspace', [
            SplitPanel(
              initialValue: 0.7,
              left: EditorShell(
                openTabs: session.tabs.openTabs,
                activeFile: session.tabs.activeFile,
                fileTree: _buildFileTree(session),
                editorOverlay: _buildEditorOverlay(session),
                onSwitchFile: session.tabs.switchFile,
                onCloseFile: session.tabs.closeFile,
                bottomPanel: _buildBottomPanel(session),
              ),
              right: _buildPreviewPanel(session),
            ),
          ]),
          Footer(
            statusLabel: _errorMessage ?? session.tabs.errorMessage ?? session.tabs.warningMessage ?? loadingStatus,
          ),
        ]),
      ),
    ]);
  }

  Component _buildBottomPanel(_WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.console,
      builder: (context) => ListenableBuilder(
        listenable: session.diagnostics,
        builder: (context) => BottomPanel(
          diagnostics: session.diagnostics.diagnostics,
          hasMoreDiagnostics: session.diagnostics.hasMoreDiagnostics,
          activeFile: session.tabs.activeFile,
          logs: session.console.logs,
          onClearConsole: session.console.clear,
          onOpenDiagnostic: (fileName, diagnostic) {
            unawaited(session.diagnostics.openDiagnostic(fileName, diagnostic));
          },
        ),
      ),
    );
  }

  Component _buildEditorOverlay(_WorkspaceSession session) {
    return PubspecEditorActions(
      activeFile: session.tabs.activeFile,
      saveAllFiles: session.tabs.saveAllTabs,
      events: session.events,
      onPubGet: (workspacePath) => session.repository.pubGet(
        path: workspacePath,
        projectRoot: _projectDir,
      ),
      onPubClean: (workspacePath) => session.repository.pubClean(path: workspacePath),
    );
  }

  Component _buildFileTree(_WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.fileTree,
      builder: (context) => FileTreeView(
        state: session.fileTree.state,
        actions: session.fileTree.actions,
      ),
    );
  }

  Component _buildPreviewPanel(_WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.preview,
      builder: (context) => PreviewContainer(
        preview: session.preview,
        activeFile: session.tabs.activeFile,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_session.dispose(closeWorker: true));
    super.dispose();
  }

  static List<StyleRule> get styles => [
    css('.app-shell').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
    ),
    css('.app-workspace-container').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.app-workspace').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
