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

import 'app_styles.dart';
import 'features/bottom_panel/views/bottom_panel.dart';
import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/components/editor_shell.dart';
import 'features/editor/components/error_toast.dart';
import 'features/editor/components/main_editor_actions.dart';
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/editor/components/small_screen_tab_bar.dart';
import 'features/editor/models/tab_descriptor.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/persistence/persisted_project_state.dart';
import 'features/persistence/persistence_notice_banner.dart';
import 'features/persistence/project_conflict_dialog.dart';
import 'features/persistence/project_persistence_controller.dart';
import 'features/persistence/project_persistence_state.dart';
import 'features/persistence/project_store.dart';
import 'features/persistence/restore_last_project_button.dart';
import 'features/preview/models/preview_state.dart';
import 'features/preview/models/run_mode.dart';
import 'features/preview/view/preview_container.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/app_bar.dart';
import 'features/shared/components/command_palette.dart';
import 'features/shared/components/context_menu.dart';
import 'features/shared/components/error_dialog.dart';
import 'features/shared/components/footer.dart';
import 'features/shared/components/shortcut_definitions.dart';
import 'features/shared/components/split_panel.dart';
import 'features/shared/events/log_event.dart';
import 'features/shared/events/open_console_event.dart';
import 'features/shared/sdk_info.dart';
import 'features/shared/task_status.dart';
import 'features/startup/initial_project_state.dart';
import 'features/startup/project_loader.dart';
import 'features/startup/project_request.dart';
import 'features/startup/project_source.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/workspace_lifecycle.dart';
import 'features/workspace/workspace_session.dart';
import 'sdks.g.dart';

/// Smallest screen width when the screen is considered to be a large screen.
const minLargeScreenWidth = 866.0;

Future<Project> _loadProjectSource(ProjectSource source) => source.loadProject();

/// The deliberately small first production slice of DartPad.
final class App extends StatefulComponent {
  const App({
    this.initialUri,
    this.projectStore,
    this.restoreOfferDuration = const Duration(seconds: 30),
    this.loadSource = _loadProjectSource,
    this.createRepository = WorkspaceRepository.create,
    super.key,
  });

  final Uri? initialUri;
  final ProjectStore? projectStore;
  final Duration restoreOfferDuration;
  final Future<Project> Function(ProjectSource source) loadSource;
  final WorkspaceRepository Function({
    required AppEventBus events,
    required SdkInfo sdk,
    required TaskStatusController taskStatus,
    WorkspaceResourceApi? localApi,
  })
  createRepository;

  @override
  State<App> createState() => _AppState();

  @css
  static List<StyleRule> get styles => _AppState.styles;
}

/// Composition root – wires all services and drives the startup lifecycle.
final class _AppState extends State<App> {
  late final bool _isEmbedMode;

  late final ProjectPersistenceController _persistence;

  /// Request used to open the current project, including its original query.
  Uri _projectUri = Uri();

  bool _isLargeScreen = true;

  /// Owns the workspace currently rendered and its worker resources.
  WorkspaceSession? _activeSession;

  /// Access for UI callbacks that require an existing workspace session.
  WorkspaceSession get _session => _activeSession!;

  /// Tracks source loading and file import before a worker session is ready.
  final TaskStatusController _loadingTasks = TaskStatusController();

  /// Incremented for each project load and on disposal. Async work compares its
  /// captured generation with this value to ignore superseded results.
  int _loadGeneration = 0;

  /// Load generation that installed [_activeSession], used to reject callbacks
  /// from that session once a newer project load has started.
  int _sessionLoadGeneration = 0;

  /// Blocks project resets and SDK switches during workspace preparation.
  /// Cleared when the worker is ready. File editing can start before that.
  bool _isInitializingWorkspace = true;

  /// Project root relative to the workspace; an empty string means its root.
  String get _projectDir => _activeSession?.initialProject.root ?? '';

  /// Failure shown when source loading, workspace preparation or SDK switching fails.
  String? _workspacePreparationFailure;

  /// Original request to retry without restoring after saved-project import
  /// fails. Also selects the restore failure message and Start fresh action.
  Uri? _failedRestoreUri;
  bool _isCommandPaletteOpen = false;

  GlobalStateKey<SplitPanelState> _previewSplitKey = GlobalStateKey<SplitPanelState>();

  SmallScreenTab _selectedSmallScreenTab = .code;
  StreamSubscription<web.Event>? _resizeSubscription;
  StreamSubscription<web.KeyboardEvent>? _keySubscription;

  SdkInfo get _currentSdk => _activeSession?.repository.sdk ?? defaultSdk;

  @override
  void initState() {
    super.initState();
    _isEmbedMode = ProjectRequest.isEmbedUri(component.initialUri ?? Uri.base);
    _persistence = ProjectPersistenceController(
      enabled: !_isEmbedMode,
      store: component.projectStore,
      restoreOfferDuration: component.restoreOfferDuration,
      restoreProject: (id) => _loadProject(_projectUri, restoreProjectId: id),
    )..addListener(_onPersistenceChanged);
    _isLargeScreen = web.window.innerWidth >= minLargeScreenWidth;
    _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
      _updateScreenSize();
    });
    _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_handleGlobalKeyDown);

    unawaited(_loadProject(component.initialUri ?? Uri.base));
  }

  /// Opens either the URL's source or a saved project, including subsequent
  /// project switches. Only the latest load may replace the visible session.
  Future<void> _loadProject(Uri uri, {bool startFresh = false, String? restoreProjectId}) async {
    final generation = ++_loadGeneration;
    setState(() {
      _projectUri = uri;
      _isInitializingWorkspace = true;
      _workspacePreparationFailure = null;
      _failedRestoreUri = null;
    });
    PersistenceLoadStrategy? loadStrategy;
    try {
      await _loadingTasks.runTask(TaskKind.loadingCode, () async {
        final request = ProjectRequest.fromUri(uri);
        final strategy = await _persistence.prepareLoad(
          request,
          startFresh: startFresh,
          restoreProjectId: restoreProjectId,
        );
        loadStrategy = strategy;
        if (!_isCurrentLoad(generation)) {
          return;
        }
        final project = switch (strategy.restoreProjectId) {
          final id? => await _loadSavedProject(id),
          null => await _loadProjectFromSource(request),
        };
        if (!_isCurrentLoad(generation)) {
          return;
        }
        await _openProject(project, generation: generation, restoreCandidateId: strategy.offerProjectId);
      }, blocksPreview: true);
    } catch (error) {
      if (_isCurrentLoad(generation)) {
        _showProjectLoadFailure(
          error,
          uri: uri,
          restoring: restoreProjectId != null || loadStrategy?.restoreProjectId != null,
          restoreCandidateId: loadStrategy?.offerProjectId,
        );
      }
    }
  }

  bool _isCurrentLoad(int generation) => mounted && generation == _loadGeneration;

  Future<_LoadedProject> _loadProjectFromSource(ProjectRequest request) async {
    final contents = await component.loadSource(request.source);
    return _LoadedProject(
      initialState: InitialProjectState.resolve(request, contents, availableSdks),
      contents: contents,
    );
  }

  Future<_LoadedProject> _loadSavedProject(String id) async {
    final saved = await _persistence.claim(id);
    return _LoadedProject(
      initialState: saved.state.initialProject(availableSdks),
      contents: saved.state.project,
      saved: saved,
    );
  }

  /// Imports files before creating worker resources. Until a session takes
  /// ownership, this method also cleans up cancelled or failed imports.
  Future<void> _openProject(_LoadedProject project, {required int generation, String? restoreCandidateId}) async {
    final localApi = MemoryWorkspaceResourceApi();
    WorkspaceSession? session;
    try {
      final snapshot = project.saved?.state;
      await _writeProject(localApi, contents: project.contents, snapshot: snapshot);
      if (!_isCurrentLoad(generation)) {
        return;
      }
      session = _replaceWorkspaceSession(project.initialState, localApi: localApi, generation: generation);
      if (snapshot != null) {
        _persistence.reportRestoredSdk(saved: snapshot.sdk, actual: project.initialState.sdk);
      }
      unawaited(
        _initializeWorkspace(
          session,
          tabs: snapshot?.tabs
              .where((tab) => tab.origin == EditorTabOrigin.external || snapshot.files.containsKey(tab.path))
              .toList(),
          activeFile: snapshot?.activeFile,
          restoring: snapshot != null,
          projectId: project.saved?.id,
          restoreCandidateId: restoreCandidateId,
        ),
      );
    } finally {
      if (session == null) {
        await localApi.dispose();
      }
    }
  }

  /// Installs a session and retires the old one after its editor subtree has
  /// unmounted. A compatible worker is reused after that disposal barrier.
  WorkspaceSession _replaceWorkspaceSession(
    InitialProjectState project, {
    required MemoryWorkspaceResourceApi localApi,
    required int generation,
  }) {
    final oldSession = _activeSession;
    final worker = oldSession?.repository.dartpad;
    final reuseWorker = worker != null && oldSession!.repository.sdk == project.sdk;
    final previousDisposed = Completer<void>();
    final events = AppEventBus();
    final taskStatus = TaskStatusController();
    final repository = reuseWorker
        ? WorkspaceRepository.resetAndCreate(
            events: events,
            worker: worker,
            sdk: project.sdk,
            taskStatus: taskStatus,
            localApi: localApi,
            previousWorkspaceDisposed: previousDisposed.future,
          )
        : component.createRepository(events: events, sdk: project.sdk, taskStatus: taskStatus, localApi: localApi);
    final session = WorkspaceSession.create(repository, initialProject: project, initialMode: project.mode);
    oldSession?.preview.removeListener(_onPreviewStateChanged);
    session.preview.addListener(_onPreviewStateChanged);
    setState(() {
      _previewSplitKey = GlobalStateKey<SplitPanelState>();
      _activeSession = session;
      _sessionLoadGeneration = generation;
    });
    if (oldSession != null) {
      disposeAfterWorkspaceUnmount(context, () async {
        try {
          await oldSession.dispose(closeWorker: !reuseWorker);
        } finally {
          previousDisposed.complete();
        }
      });
    }
    return session;
  }

  void _showProjectLoadFailure(Object error, {required Uri uri, required bool restoring, String? restoreCandidateId}) {
    final oldSession = _activeSession;
    oldSession?.preview.removeListener(_onPreviewStateChanged);
    setState(() {
      _activeSession = null;
      _isCommandPaletteOpen = false;
      _isInitializingWorkspace = false;
      _workspacePreparationFailure = error.toString();
      _failedRestoreUri = restoring ? uri : null;
    });
    if (oldSession != null) {
      disposeAfterWorkspaceUnmount(context, () => oldSession.dispose(closeWorker: true));
    }
    if (!restoring && restoreCandidateId != null) {
      _persistence.offerRestore(restoreCandidateId);
    }
  }

  Future<void> _writeProject(
    MemoryWorkspaceResourceApi api, {
    required Project contents,
    PersistedProjectState? snapshot,
  }) async {
    await ProjectLoader.writeFiles(api.root, contents);
    if (snapshot != null) {
      for (final folder in snapshot.folders) {
        await api.createFolder(folder);
      }
    }
  }

  void _onPersistenceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _updateScreenSize() {
    final isLarge = web.window.innerWidth >= minLargeScreenWidth;
    if (_isLargeScreen != isLarge) {
      setState(() {
        _isLargeScreen = isLarge;
      });
    }
  }

  void _onPreviewStateChanged() {
    final state = _session.preview.state;
    if (state is PreviewStarting || state is PreviewRestarting || state is PreviewRunning) {
      if (!_isLargeScreen) {
        if (_selectedSmallScreenTab != .output) {
          setState(() {
            _selectedSmallScreenTab = .output;
          });
        }
      } else if (_previewSplitKey.currentState?.isRightCollapsed ?? false) {
        _previewSplitKey.currentState?.split();
      }
    }
  }

  bool _isCurrent(WorkspaceSession session) =>
      mounted && _sessionLoadGeneration == _loadGeneration && identical(_activeSession, session);

  /// Opens the initial tabs and starts persistence before waiting for the worker.
  /// Once the worker is ready, resets are enabled again while Pub and LSP
  /// initialization continue in the background.
  Future<void> _initializeWorkspace(
    WorkspaceSession session, {
    List<TabDescriptor>? tabs,
    String? activeFile,
    bool restoring = false,
    String? projectId,
    String? restoreCandidateId,
  }) async {
    try {
      await session.openProjectFiles(restoredTabs: tabs, activeFile: activeFile, continueOnTabOpenError: restoring);
      if (!_isCurrent(session)) {
        return;
      }
      _persistence.attach(session, projectId: projectId);
      await _persistence.flush();
      if (!_isCurrent(session)) {
        return;
      }
      if (restoreCandidateId != null) {
        _persistence.offerRestore(restoreCandidateId);
      }
      final workspace = await session.repository.readyWorkspace;
      if (!_isCurrent(session)) {
        return;
      }
      setState(() => _isInitializingWorkspace = false);
      unawaited(_initializeWorkspaceTools(session, workspace, session.initialProject));
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) {
        return;
      }
      session.events.dispatch(
        LogEvent('Workspace preparation failed.', level: Level.SEVERE, error: error, stackTrace: stackTrace),
      );
      setState(() {
        _isInitializingWorkspace = false;
        _workspacePreparationFailure = 'The workspace could not be initialized: $error';
      });
    }
  }

  Future<void> _initializeWorkspaceTools(
    WorkspaceSession session,
    Workspace workspace,
    InitialProjectState project,
  ) async {
    var preparationSucceeded = true;
    if (project.hasPubspec) {
      final packageRoot = project.root;
      if (!_isCurrent(session)) {
        return;
      }
      try {
        await session.repository.pubGet(
          path: packageRoot,
          projectRoot: packageRoot,
        );
      } catch (error, stackTrace) {
        preparationSucceeded = false;
        if (_isCurrent(session)) {
          session.events.dispatch(
            LogEvent(
              'Pub get failed.',
              level: Level.SEVERE,
              error: error,
              stackTrace: stackTrace,
            ),
          );
          setState(() {
            _workspacePreparationFailure = 'Pub get failed while preparing the workspace.';
          });
        }
      }
    }

    if (!_isCurrent(session)) {
      return;
    }

    if (preparationSucceeded && project.request.autoRun && session.preview.entrypoint != null) {
      unawaited(session.preview.runCurrent());
    }
    await _initializeAnalyzer(session, workspace, project.root);
  }

  /// Starts the language server with an editor root derived from [packageRoot].
  ///
  /// [packageRoot] is relative to the complete virtual [workspace]. It is
  /// `null` when no Dart package was detected and empty when the package is
  /// rooted at the workspace itself. The resulting editor root URI determines
  /// where analysis starts.
  Future<void> _initializeAnalyzer(
    WorkspaceSession session,
    Workspace workspace,
    String? packageRoot,
  ) async {
    try {
      session.analyzerStatus.beginInitialization();
      final languageServer = await workspace.startLanguageServer();
      if (!_isCurrent(session)) {
        await languageServer.stop();
        return;
      }

      final rootWorkspaceUri = workspace.workspaceFolder;
      final editorRootUri = resolveEditorRootUri(
        rootWorkspaceUri,
        packageRoot,
      );
      final languageServerClient = LanguageServerClient(
        languageServer: languageServer,
        rootWorkspaceUri: rootWorkspaceUri,
        editorRootUri: editorRootUri,
        workspaceChangeEvents: session.repository.workspaceResourceApi.changeEvents,
        documentEditsHandler: (filePath, edits) async {
          final tab = session.tabs.getTab(filePath);
          if (tab is WorkspaceCodeMirrorTab) {
            await tab.applyEdits(edits);
          } else {
            final file = session.repository.root.getFile(filePath);
            await file.writeContent(
              LanguageServerClient.applyEdits(await file.readContent(), edits),
            );
          }
        },
        displayFileHandler: (uri) {
          final workspacePath = relativePathWithinWorkspace(
            uri,
            rootWorkspaceUri,
          );
          return workspacePath == null
              ? session.tabs.openExternalFile(uri)
              : session.tabs.openWorkspaceFile(workspacePath);
        },
      );
      if (!_isCurrent(session)) {
        await languageServerClient.dispose();
        await languageServer.stop();
        return;
      }

      session.attachLanguageServer(
        server: languageServer,
        client: languageServerClient,
        projectRoot: packageRoot,
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) {
        return;
      }
      session.analyzerStatus.markUnavailable();
      session.events.dispatch(
        LogEvent(
          'Analyzer initialization failed.',
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void _resetWorkspace(ProjectRequest request) {
    if (_isInitializingWorkspace || _persistence.hasConflict) {
      return;
    }
    final newSearch = request.search;
    if (web.window.location.search != newSearch) {
      web.window.history.pushState(null, '', newSearch.isEmpty ? web.window.location.pathname : newSearch);
    }
    unawaited(_loadProject(Uri.base.replace(queryParameters: request.query)));
  }

  /// Rebuilds worker resources from a copy of the current workspace, keeping the snapshot.
  Future<void> _switchSdk(SdkInfo newSdk) async {
    final oldSession = _activeSession;
    if (oldSession == null || _isInitializingWorkspace || _persistence.hasConflict || newSdk == _currentSdk) {
      return;
    }
    setState(() => _isInitializingWorkspace = true);
    try {
      await oldSession.tabs.saveAllTabs();
      final entrypoint = oldSession.preview.entrypoint;
      final mode = await RunMode.resolve(
        workspace: oldSession.repository.workspaceResourceApi,
        sdk: newSdk,
        entrypoint: entrypoint,
        modeOverride: oldSession.initialProject.request.mode,
      );
      if (!_isCurrent(oldSession)) {
        return;
      }
      final localApi = await oldSession.repository.copyFiles();
      if (!_isCurrent(oldSession)) {
        await localApi.dispose();
        return;
      }
      await _persistence.stop();
      final paths = oldSession.tabSnapshot;
      final activeFile = oldSession.tabs.activeFile;
      final next = WorkspaceSession.create(
        component.createRepository(
          events: AppEventBus(),
          sdk: newSdk,
          taskStatus: TaskStatusController(),
          localApi: localApi,
        ),
        initialProject: oldSession.initialProject,
        initialMode: mode,
        entrypoint: entrypoint,
      );
      oldSession.preview.removeListener(_onPreviewStateChanged);
      next.preview.addListener(_onPreviewStateChanged);
      setState(() {
        _previewSplitKey = GlobalStateKey<SplitPanelState>();
        _activeSession = next;
        _workspacePreparationFailure = null;
      });
      unawaited(_initializeWorkspace(next, tabs: paths, activeFile: activeFile, projectId: _persistence.projectId));
      disposeAfterWorkspaceUnmount(context, () => oldSession.dispose(closeWorker: true));
    } catch (error) {
      if (!_isCurrent(oldSession)) {
        return;
      }
      setState(() {
        _isInitializingWorkspace = false;
        _workspacePreparationFailure = 'SDK switch failed: $error';
      });
    }
  }

  @override
  Component build(BuildContext context) => Component.fragment([
    _buildWorkspace(context),
    if (_persistence.hasConflict)
      ProjectConflictDialog(
        busy: _persistence.conflict == ProjectOwnershipConflict.resolving,
        onUseLatest: () => unawaited(_persistence.resolveConflict(useLatest: true)),
        onKeepVersion: () => unawaited(_persistence.resolveConflict(useLatest: false)),
      ),
  ]);

  Component? get _restoreAction {
    final offer = _persistence.restoreOffer;
    return offer == null
        ? null
        : RestoreLastProjectButton(
            key: ValueKey(offer.projectId),
            expires: offer.expires,
            duration: offer.duration,
            onRestore: () => unawaited(_persistence.restoreLastProject()),
          );
  }

  TaskStatusController get _activeTaskStatus {
    final session = _activeSession;
    if (session == null || _loadingTasks.current?.isRunning == true) {
      return _loadingTasks;
    }
    return session.taskStatus;
  }

  Component _buildWorkspace(BuildContext context) {
    final session = _activeSession;
    if (session == null) {
      return div(
        classes: 'app-shell',
        attributes: {if (_persistence.hasConflict) 'inert': ''},
        [
          if (_persistence.notice case final notice?) PersistenceNoticeBanner(notice: notice),
          if (!_isEmbedMode)
            AppBar(
              isSmallScreen: !_isLargeScreen,
              restoreAction: _restoreAction,
              onSelectExample: _isInitializingWorkspace
                  ? null
                  : (example) => _resetWorkspace(ProjectRequest.example(example.id)),
              isEmbedMode: _isEmbedMode,
            ),
          div(classes: 'app-workspace-container', [
            div(classes: 'app-workspace', [
              if (_failedRestoreUri case final uri?)
                div(
                  classes: 'restore-project-failure',
                  attributes: const {'role': 'alert'},
                  [
                    const h2([.text('Restoring your project failed.')]),
                    const p([
                      .text(
                        'Start fresh to load the original project. Your previous work will remain in your saved history.',
                      ),
                    ]),
                    button(
                      onClick: () => unawaited(_loadProject(uri, startFresh: true)),
                      const [.text('Start fresh')],
                    ),
                  ],
                )
              else if (_workspacePreparationFailure case final failure?)
                ErrorDialog(errorMessage: failure)
              else
                const p([.text('Loading project...')]),
            ]),
            if (!_isEmbedMode)
              Footer(
                taskStatus: _activeTaskStatus,
                isSmallScreen: !_isLargeScreen,
                currentSdk: _currentSdk,
                onSelectSdk: _isInitializingWorkspace ? null : _switchSdk,
              ),
          ]),
        ],
      );
    }
    return div(
      classes: 'app-shell',
      attributes: {if (_persistence.hasConflict) 'inert': ''},
      [
        if (_persistence.notice case final notice?) PersistenceNoticeBanner(notice: notice),
        if (!_isEmbedMode || !_isLargeScreen)
          AppBar(
            isSmallScreen: !_isLargeScreen,
            restoreAction: _restoreAction,
            onSelectExample: _isInitializingWorkspace
                ? null
                : (example) => _resetWorkspace(ProjectRequest.example(example.id)),
            isEmbedMode: _isEmbedMode,
            smallScreenTabBar: !_isLargeScreen
                ? SmallScreenTabBar(
                    selectedTab: _selectedSmallScreenTab,
                    onTabSelected: (tab) => setState(() => _selectedSmallScreenTab = tab),
                  )
                : null,
          ),
        ListenableBuilder(
          // Replacing the session must unmount its editors, including CodeMirror
          // NodeContainers. Starting a load keeps the existing subtree intact.
          key: ValueKey(session),
          listenable: session.tabs,
          builder: (context) => div(classes: 'app-workspace-container', [
            div(classes: 'app-workspace', [
              if (_isLargeScreen)
                SplitPanel(
                  key: _previewSplitKey,
                  initialValue: session.initialProject.request.initialSplitRatio,
                  canCollapseRight: true,
                  minValue: session.initialProject.request.isLegacyEmbedMode ? 0.05 : 0.3,
                  maxValue: session.initialProject.request.isLegacyEmbedMode ? 0.95 : 0.85,
                  left: EditorShell(
                    openTabs: session.tabs.openTabs,
                    activeFile: session.tabs.activeFile,
                    fileTree: _buildFileTree(session),
                    editorOverlay: _buildEditorOverlay(session),
                    onSwitchFile: session.tabs.switchFile,
                    onCloseFile: session.tabs.closeFile,
                    bottomPanel: _buildBottomPanel(session),
                    contextMenu: session.contextMenu,
                    isEmbedMode: _isEmbedMode,
                  ),
                  right: _buildPreviewPanel(session),
                )
              else
                EditorShell(
                  openTabs: session.tabs.openTabs,
                  activeFile: session.tabs.activeFile,
                  fileTree: _buildFileTree(session),
                  editorOverlay: _buildEditorOverlay(session),
                  onSwitchFile: session.tabs.switchFile,
                  onCloseFile: session.tabs.closeFile,
                  bottomPanel: _buildBottomPanel(session),
                  contextMenu: session.contextMenu,
                  isEmbedMode: _isEmbedMode,
                  smallScreenPreviewPanel: _selectedSmallScreenTab == .output ? _buildPreviewPanel(session) : null,
                ),
            ]),
            if (!_isEmbedMode)
              Footer(
                taskStatus: _activeTaskStatus,
                statusMessage: session.tabs.errorMessage ?? session.tabs.warningMessage,
                isSmallScreen: !_isLargeScreen,
                currentSdk: _currentSdk,
                onSelectSdk: _isInitializingWorkspace ? null : _switchSdk,
              ),
          ]),
        ),
        ListenableBuilder(
          listenable: session.contextMenu,
          builder: (context) => ContextMenu(
            key: const ValueKey('active-context-menu'),
            x: session.contextMenu.x,
            y: session.contextMenu.y,
            items: session.contextMenu.items,
            isOpen: session.contextMenu.isOpen,
            onClose: session.contextMenu.hide,
          ),
        ),
        if (_isCommandPaletteOpen)
          CommandPalette.fromSession(
            key: const ValueKey('active-command-palette'),
            session: session,
            projectDir: _projectDir,
            onClose: () {
              setState(() {
                _isCommandPaletteOpen = false;
              });
            },
          ),
      ],
    );
  }

  Component _buildBottomPanel(WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.console,
      builder: (context) => ListenableBuilder(
        listenable: session.diagnostics,
        builder: (context) => BottomPanel(
          diagnostics: session.diagnostics.diagnostics,
          hasMoreDiagnostics: session.diagnostics.hasMoreDiagnostics,
          logs: session.console.logs,
          onClearConsole: session.console.clear,
          events: session.events,
          onOpenDiagnostic: (fileName, diagnostic) {
            unawaited(
              session.diagnostics.openDiagnostic(fileName, diagnostic).catchError((Object _) {
                // The tab model has already reported the load failure.
              }),
            );
          },
        ),
      ),
    );
  }

  Component _buildEditorOverlay(WorkspaceSession session) {
    final activeTab = session.tabs.activeTab;

    return .fragment([
      if (activeTab?.origin == EditorTabOrigin.workspace) ...[
        PubspecEditorActions(
          activeFile: session.tabs.activeFile,
          saveAllFiles: session.tabs.saveAllTabs,
          events: session.events,
          onPubGet: (workspacePath) => session.repository.pubGet(
            path: workspacePath,
            projectRoot: _projectDir,
          ),
        ),
        if (activeTab is CodeMirrorTab)
          MainEditorActions(
            activeFile: session.tabs.activeFile,
            getContent: () => activeTab.content,
            tabUpdates: activeTab.onUpdate,
            runAvailability: session.preview,
            onRun: (entrypointPath) => session.preview.runCode(entrypointPath),
          ),
      ],
      ErrorToast(
        key: const ValueKey('editor-error-toast'),
        events: session.events,
      ),
    ]);
  }

  Component _buildFileTree(WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.fileTree,
      builder: (context) => FileTreeView(
        state: session.fileTree.state,
        actions: session.fileTree.actions,
        contextMenu: session.contextMenu,
      ),
    );
  }

  Component _buildPreviewPanel(WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.preview,
      builder: (context) => PreviewContainer(
        preview: session.preview,
        taskStatus: session.taskStatus,
        activeFile: session.tabs.activeFile,
        workspacePreparationFailure: _workspacePreparationFailure,
        onOpenConsole: () => _openConsole(session),
      ),
    );
  }

  void _openConsole(WorkspaceSession session) {
    if (!_isCurrent(session)) {
      return;
    }
    if (!_isLargeScreen && _selectedSmallScreenTab != SmallScreenTab.code) {
      setState(() {
        _selectedSmallScreenTab = SmallScreenTab.code;
      });
      context.binding.addPostFrameCallback(() {
        if (_isCurrent(session)) {
          session.events.dispatch(const OpenConsoleEvent());
        }
      });
      return;
    }
    session.events.dispatch(const OpenConsoleEvent());
  }

  void _handleGlobalKeyDown(web.KeyboardEvent event) {
    if (_persistence.hasConflict || event.defaultPrevented || event.repeat) {
      return;
    }
    final isModifier = isMac ? event.metaKey : event.ctrlKey;
    if (isModifier && !event.altKey && !event.shiftKey && event.key == 'Enter') {
      event.preventDefault();
      _activeSession?.runOrHotReload();
    } else if (isModifier && !event.altKey && event.shiftKey && (event.key == 'p' || event.key == 'P')) {
      event.preventDefault();
      setState(() {
        _isCommandPaletteOpen = !_isCommandPaletteOpen;
      });
    }
  }

  @override
  void dispose() {
    _resizeSubscription?.cancel();
    _keySubscription?.cancel();
    _persistence.removeListener(_onPersistenceChanged);
    _persistence.dispose();
    _loadGeneration++;
    _activeSession?.preview.removeListener(_onPreviewStateChanged);
    final session = _activeSession;
    unawaited(
      _persistence.closed.whenComplete(() => session?.dispose(closeWorker: true)).catchError((
        Object error,
        StackTrace stackTrace,
      ) {
        Logger('App').warning('App cleanup failed.', error, stackTrace);
      }),
    );
    _loadingTasks.dispose();
    super.dispose();
  }

  static List<StyleRule> get styles => [
    ...ProjectConflictDialog.styles,
    ...RestoreLastProjectButton.styles,
    css('.restore-project-failure').styles(padding: .all(28.px)),
    css('.restore-project-failure button').styles(
      padding: .symmetric(vertical: 10.px, horizontal: 16.px),
      border: .all(color: colorPrimary, width: 1.px),
      radius: .circular(6.px),
      cursor: .pointer,
      color: colorOnPrimary,
      fontSize: 14.px,
      backgroundColor: colorPrimary,
    ),
    ...PersistenceNoticeBanner.styles,
    ...ContextMenu.styles,
    ...CommandPalette.styles,
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

/// Source contents and resolved startup options, before workspace creation.
/// A saved entry additionally supplies its identity and previous editor tabs.
final class _LoadedProject {
  const _LoadedProject({required this.initialState, required this.contents, this.saved});

  final InitialProjectState initialState;
  final Project contents;
  final StoredProject? saved;
}
