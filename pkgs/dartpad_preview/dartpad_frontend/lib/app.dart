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

import 'features/bottom_panel/views/bottom_panel.dart';
import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/components/editor_shell.dart';
import 'features/editor/components/error_toast.dart';
import 'features/editor/components/main_editor_actions.dart';
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/editor/components/small_screen_tab_bar.dart';
import 'features/editor/models/tab_descriptor.dart';
import 'features/filetree/file_tree_view.dart';
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
import 'features/shared/components/task_status_indicator.dart';
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
    this.loadSource = _loadProjectSource,
    this.createRepository = WorkspaceRepository.create,
    super.key,
  });

  final Uri? initialUri;
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
  bool _isLargeScreen = true;
  WorkspaceSession? _activeSession;
  WorkspaceSession get _session => _activeSession!;
  final TaskStatusController _loadingTasks = TaskStatusController();
  int _loadGeneration = 0;
  int _activeLoadGeneration = 0;

  /// Incremented on every workspace reset. Used as a [ValueKey] so Jaspr
  /// unmounts the old workspace subtree (including CodeMirror NodeContainers)
  /// rather than trying to update them in-place.
  int _workspaceGeneration = 0;

  bool _isInitializingWorkspace = true;
  String get _projectDir => _activeSession?.initialProject.root ?? '';
  String? _workspacePreparationFailure;
  bool _isCommandPaletteOpen = false;

  GlobalStateKey<SplitPanelState> _previewSplitKey = GlobalStateKey<SplitPanelState>();

  SmallScreenTab _selectedSmallScreenTab = .code;
  StreamSubscription<web.Event>? _resizeSubscription;
  StreamSubscription<web.KeyboardEvent>? _keySubscription;

  SdkInfo get _currentSdk => _activeSession?.repository.sdk ?? defaultSdk;

  @override
  void initState() {
    super.initState();
    _isEmbedMode = (component.initialUri ?? Uri.base).queryParameters['embed'] == 'true';
    _isLargeScreen = web.window.innerWidth >= minLargeScreenWidth;
    _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
      _updateScreenSize();
    });
    _keySubscription = web.EventStreamProviders.keyDownEvent.forTarget(web.document).listen(_handleGlobalKeyDown);

    unawaited(_loadInitialProject(component.initialUri ?? Uri.base));
  }

  Future<void> _loadInitialProject(Uri uri) async {
    final generation = ++_loadGeneration;
    setState(() {
      _isInitializingWorkspace = true;
      _workspacePreparationFailure = null;
    });
    final localApi = MemoryWorkspaceResourceApi();
    var transferredToRepository = false;
    try {
      final project = await _loadingTasks.runTask(TaskKind.loadingCode, () async {
        final request = ProjectRequest.fromUri(uri);
        final contents = await component.loadSource(request.source);
        final initialProject = InitialProjectState.resolve(request, contents, availableSdks);
        if (mounted && generation == _loadGeneration) {
          await ProjectLoader.writeFiles(localApi.root, contents);
        }
        return initialProject;
      }, blocksPreview: true);
      if (!mounted || generation != _loadGeneration) {
        await localApi.dispose();
        return;
      }
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
      transferredToRepository = true;
      final session = WorkspaceSession.create(repository, initialProject: project, initialMode: project.mode);
      oldSession?.preview.removeListener(_onPreviewStateChanged);
      session.preview.addListener(_onPreviewStateChanged);
      setState(() {
        _workspaceGeneration++;
        _previewSplitKey = GlobalStateKey<SplitPanelState>();
        _activeSession = session;
        _activeLoadGeneration = generation;
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
      unawaited(_initializeWorkspace(session));
    } catch (error) {
      if (!transferredToRepository) {
        await localApi.dispose();
      }
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      final oldSession = _activeSession;
      oldSession?.preview.removeListener(_onPreviewStateChanged);
      setState(() {
        _activeSession = null;
        _isCommandPaletteOpen = false;
        _isInitializingWorkspace = false;
        _workspacePreparationFailure = error.toString();
      });
      if (oldSession != null) {
        disposeAfterWorkspaceUnmount(context, () => oldSession.dispose(closeWorker: true));
      }
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
      mounted && _activeLoadGeneration == _loadGeneration && identical(_activeSession, session);

  /// Loads the workspace and project. Once the initial file has been opened,
  /// the workspace is usable and another reset may be requested. Pub and LSP
  /// initialization deliberately continue in the background.
  Future<void> _initializeWorkspace(
    WorkspaceSession session, {
    List<TabDescriptor>? tabs,
    String? activeFile,
  }) async {
    try {
      await session.openProjectFiles(restoredTabs: tabs, activeFile: activeFile);
      if (!_isCurrent(session)) {
        return;
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

    if (preparationSucceeded && session.preview.entrypoint != null) {
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
              ? session.tabs.openSystemFile(uri)
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
    if (_isInitializingWorkspace) {
      return;
    }
    final newSearch = request.search;
    if (web.window.location.search != newSearch) {
      web.window.history.pushState(null, '', newSearch.isEmpty ? web.window.location.pathname : newSearch);
    }
    unawaited(_loadInitialProject(Uri.base.replace(queryParameters: request.query)));
  }

  /// Rebuilds worker resources from a copy of the current workspace, keeping the snapshot.
  Future<void> _switchSdk(SdkInfo newSdk) async {
    final oldSession = _activeSession;
    if (oldSession == null || _isInitializingWorkspace || newSdk == _currentSdk) {
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
        _workspaceGeneration++;
        _previewSplitKey = GlobalStateKey<SplitPanelState>();
        _activeSession = next;
        _workspacePreparationFailure = null;
      });
      unawaited(_initializeWorkspace(next, tabs: paths, activeFile: activeFile));
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
  Component build(BuildContext context) {
    final session = _activeSession;
    if (session == null) {
      return div(classes: 'app-shell', [
        if (!_isEmbedMode)
          AppBar(
            onSelectExample: _isInitializingWorkspace
                ? null
                : (example) => _resetWorkspace(ProjectRequest.example(example.id)),
            isEmbedMode: _isEmbedMode,
          ),
        TaskStatusIndicator(controller: _loadingTasks),
        if (_workspacePreparationFailure case final failure?)
          ErrorDialog(errorMessage: failure)
        else
          const p([.text('Loading project...')]),
      ]);
    }
    return div(classes: 'app-shell', [
      if (_isInitializingWorkspace) TaskStatusIndicator(controller: _loadingTasks),
      if (!_isEmbedMode || !_isLargeScreen)
        AppBar(
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
        key: ValueKey(_workspaceGeneration),
        listenable: session.tabs,
        builder: (context) => div(classes: 'app-workspace-container', [
          div(classes: 'app-workspace', [
            if (_isLargeScreen)
              SplitPanel(
                key: _previewSplitKey,
                initialValue: 0.7,
                canCollapseRight: true,
                minValue: 0.3,
                maxValue: 0.85,
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
              taskStatus: session.taskStatus,
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
    ]);
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
      if (activeTab case final tab? when !tab.origin.isReadOnly) ...[
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
    if (event.defaultPrevented || event.repeat) {
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
    _loadGeneration++;
    _activeSession?.preview.removeListener(_onPreviewStateChanged);
    unawaited(_activeSession?.dispose(closeWorker: true));
    _loadingTasks.dispose();
    super.dispose();
  }

  static List<StyleRule> get styles => [
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
