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
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/editor/components/small_screen_tab_bar.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/preview/models/preview_state.dart';
import 'features/preview/view/preview_container.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/app_bar.dart';
import 'features/shared/components/context_menu.dart';
import 'features/shared/components/footer.dart';
import 'features/shared/components/split_panel.dart';
import 'features/shared/events/log_event.dart';
import 'features/shared/events/open_console_event.dart';
import 'features/shared/sdk_info.dart';
import 'features/shared/task_status.dart';
import 'features/startup/archive_loader.dart';
import 'features/startup/example_project.dart';
import 'features/startup/gist_loader.dart';
import 'features/startup/project_loader.dart';
import 'features/workspace/data/synced_workspace_resource_api.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/workspace_lifecycle.dart';
import 'features/workspace/workspace_session.dart';
import 'sdks.g.dart';

/// Whether the application is running in embed mode (`?embed=true`).
///
/// When `true`, the [AppBar] and footer are hidden and the file tree starts
/// collapsed into a narrow rail with a toggle button.
final bool isEmbedMode = Uri.base.queryParameters['embed'] == 'true';

/// Smallest screen width when the screen is considered to be a large screen.
const minLargeScreenWidth = 866.0;

/// The deliberately small first production slice of DartPad.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();

  @css
  static List<StyleRule> get styles => AppState.styles;
}

/// Describes where the initial workspace project should be loaded from.
sealed class ProjectSource {
  const ProjectSource();

  /// Loads an example, or the default example when [sampleId] is omitted.
  const factory ProjectSource.example([String? sampleId]) = ExampleProjectSource;

  /// Captures the startup query parameters from [uri].
  factory ProjectSource.fromUri(Uri uri) => UrlProjectSource(uri.queryParameters);

  Map<String, String> get queryParameters;

  /// The query string that represents this source in the browser URL.
  String get search {
    final query = Uri(queryParameters: queryParameters).query;
    return query.isEmpty ? '' : '?$query';
  }
}

/// A project source described by URL query parameters.
final class UrlProjectSource extends ProjectSource {
  const UrlProjectSource(this.queryParameters);

  @override
  final Map<String, String> queryParameters;
}

/// A project source that always loads a packaged example.
final class ExampleProjectSource extends ProjectSource {
  const ExampleProjectSource([this.sampleId]);

  final String? sampleId;

  @override
  Map<String, String> get queryParameters => sampleId == null ? const <String, String>{} : {'sample': sampleId!};
}

/// Composition root – wires all services and drives the startup lifecycle.
class AppState extends State<App> {
  late WorkspaceSession _session;

  /// Incremented on every workspace reset. Used as a [ValueKey] so Jaspr
  /// unmounts the old workspace subtree (including CodeMirror NodeContainers)
  /// rather than trying to update them in-place.
  int _workspaceGeneration = 0;

  bool _isInitializingWorkspace = true;
  String _projectDir = '';
  String? _workspacePreparationFailure;

  bool _isLargeScreen = true;
  SmallScreenTab _selectedSmallScreenTab = .code;
  StreamSubscription<web.Event>? _resizeSubscription;

  SdkInfo _currentSdk = defaultSdk;

  @override
  void initState() {
    super.initState();
    _isLargeScreen = web.window.innerWidth >= minLargeScreenWidth;
    _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
      _updateScreenSize();
    });

    final events = AppEventBus();
    final taskStatus = TaskStatusController();
    _session = WorkspaceSession.create(
      WorkspaceRepository.create(
        events: events,
        sdk: _currentSdk,
        taskStatus: taskStatus,
      ),
    );
    _session.preview.addListener(_onPreviewStateChanged);
    unawaited(
      _initializeWorkspace(
        _session,
        source: ProjectSource.fromUri(Uri.base),
      ),
    );
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
    if (!_isLargeScreen) {
      final state = _session.preview.state;
      if (state is PreviewStarting || state is PreviewRestarting || state is PreviewRunning) {
        if (_selectedSmallScreenTab != .output) {
          setState(() {
            _selectedSmallScreenTab = .output;
          });
        }
      }
    }
  }

  bool _isCurrent(WorkspaceSession session) => mounted && identical(_session, session);

  /// Loads the workspace and project. Once the initial file has been opened,
  /// the workspace is usable and another reset may be requested. Pub and LSP
  /// initialization deliberately continue in the background.
  Future<void> _initializeWorkspace(
    WorkspaceSession session, {
    required ProjectSource source,
  }) async {
    final projectFuture = _loadProject(session, source: source);

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

      if (project == null) {
        setState(() {
          _workspacePreparationFailure ??= 'The project could not be loaded.';
        });
        unawaited(_initializeAnalyzer(session, workspace, null));
        return;
      }

      unawaited(
        _initializeWorkspaceTools(
          session,
          workspace,
          project,
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) {
        return;
      }
      session.events.dispatch(
        LogEvent(
          'Workspace preparation failed.',
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      setState(() {
        _isInitializingWorkspace = false;
        _workspacePreparationFailure = 'The workspace could not be initialized.';
      });
    }
  }

  Future<void> _initializeWorkspaceTools(
    WorkspaceSession session,
    Workspace workspace,
    LoadedProject project,
  ) async {
    var preparationSucceeded = true;
    if (project.packageRoot case final String packageRoot) {
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

    if (preparationSucceeded) {
      if (project.pathToMain case final String pathToMain when pathToMain.isNotEmpty && pathToMain.endsWith('.dart')) {
        unawaited(session.preview.runCode(pathToMain));
      }
    }

    await _initializeAnalyzer(session, workspace, project.packageRoot);
  }

  Future<void> _initializeAnalyzer(
    WorkspaceSession session,
    Workspace workspace,
    String? projectRoot,
  ) async {
    try {
      session.analyzerStatus.beginInitialization();
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

      session.attachLanguageServer(
        server: languageServer,
        client: languageServerClient,
        projectRoot: projectRoot,
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

  /// Replaces the current workspace with a fresh example workspace on the same
  /// worker. The old session is disposed only after Jaspr has unmounted its
  /// keyed subtree.
  void resetWorkspace(ProjectSource source) {
    final oldSession = _session;
    final worker = oldSession.repository.dartpad;
    if (_isInitializingWorkspace || worker == null) {
      return;
    }

    final previousWorkspaceDisposed = Completer<void>();
    final events = AppEventBus();
    final taskStatus = TaskStatusController();
    final nextSession = WorkspaceSession.create(
      WorkspaceRepository.resetAndCreate(
        events: events,
        worker: worker,
        sdk: _currentSdk,
        taskStatus: taskStatus,
        previousWorkspaceDisposed: previousWorkspaceDisposed.future,
      ),
    );
    oldSession.preview.removeListener(_onPreviewStateChanged);
    nextSession.preview.addListener(_onPreviewStateChanged);

    final newSearch = source.search;
    if (web.window.location.search != newSearch) {
      web.window.history.pushState(
        null,
        '',
        newSearch.isEmpty ? web.window.location.pathname : newSearch,
      );
    }

    setState(() {
      _workspaceGeneration++;
      _session = nextSession;
      _isInitializingWorkspace = true;
      _workspacePreparationFailure = null;
      _projectDir = '';
    });

    unawaited(
      _initializeWorkspace(
        nextSession,
        source: source,
      ),
    );
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

  /// Switches the active SDK and creates a fresh worker while preserving the
  /// in-memory workspace file system.
  void switchSdk(SdkInfo newSdk) {
    final oldSession = _session;
    if (_isInitializingWorkspace || newSdk == _currentSdk) {
      return;
    }

    final oldLocalApi = switch (oldSession.repository.workspaceResourceApi) {
      SyncedWorkspaceResourceApi(:final localApi) => localApi,
      _ => null,
    };

    final events = AppEventBus();
    final taskStatus = TaskStatusController();
    final nextSession = WorkspaceSession.create(
      WorkspaceRepository.create(
        events: events,
        sdk: newSdk,
        taskStatus: taskStatus,
        localApi: oldLocalApi,
      ),
    );

    setState(() {
      _workspaceGeneration++;
      _session = nextSession;
      _currentSdk = newSdk;
      _isInitializingWorkspace = true;
      _workspacePreparationFailure = null;
    });

    unawaited(
      _initializeSwitchSdkWorkspace(nextSession),
    );

    disposeAfterWorkspaceUnmount(
      context,
      () async {
        await oldSession.dispose(closeWorker: true);
      },
    );
  }

  Future<void> _initializeSwitchSdkWorkspace(
    WorkspaceSession session,
  ) async {
    try {
      final workspace = await session.repository.readyWorkspace;
      if (!_isCurrent(session)) {
        return;
      }

      setState(() {
        _isInitializingWorkspace = false;
      });

      final project = _projectDir.isNotEmpty
          ? LoadedProject(
              projectDir: _projectDir,
              packageRoot: _projectDir,
              entryPath: null,
            )
          : null;
      if (project == null) {
        setState(() {
          _workspacePreparationFailure = 'The current project could not be prepared for the selected SDK.';
        });
        unawaited(_initializeAnalyzer(session, workspace, null));
        return;
      }
      unawaited(
        _initializeWorkspaceTools(
          session,
          workspace,
          project,
        ),
      );
    } catch (error, stackTrace) {
      if (!_isCurrent(session)) {
        return;
      }
      session.events.dispatch(
        LogEvent(
          'Workspace preparation failed.',
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
      setState(() {
        _isInitializingWorkspace = false;
        _workspacePreparationFailure = 'The workspace could not be initialized for the selected SDK.';
      });
    }
  }

  Future<LoadedProject?> _loadProject(
    WorkspaceSession session, {
    required ProjectSource source,
  }) async {
    final params = source.queryParameters;
    var userErrorMessage = 'The project could not be loaded.';

    try {
      final LoadedProject project;
      if (params case {'archive': final String archiveUrlParam}) {
        userErrorMessage =
            'The project archive could not be downloaded. '
            'Please check that the URL is correct and accessible.';
        final archiveUrl = Uri.decodeComponent(archiveUrlParam);
        final filePathParam = params['path'];
        final filePath = filePathParam != null ? Uri.decodeComponent(filePathParam) : null;
        final pathToMainParam = params['main'];
        final pathToMain = pathToMainParam != null ? Uri.decodeComponent(pathToMainParam) : null;
        final loader = ArchiveLoader(
          archiveUrl: archiveUrl,
          filePath: filePath,
          pathToMain: pathToMain,
        );
        project = await session.taskStatus.runTask(
          TaskKind.loadingCode,
          () => loader.loadArchive(session.repository.root),
          scope: archiveUrl,
          blocksPreview: true,
        );
      } else if (params case {'package': final String packageName}) {
        userErrorMessage =
            'The package "$packageName" could not be resolved from pub.dev. '
            'Please verify the package name in the URL.';
        final pathToMainParam = params['main'];
        final pathToMain = pathToMainParam != null ? Uri.decodeComponent(pathToMainParam) : null;
        project = await session.taskStatus.runTask(
          TaskKind.loadingCode,
          () async {
            final loader = await ArchiveLoader.forPackage(
              packageName,
              pathToMain: pathToMain,
            );
            return await loader.loadArchive(session.repository.root);
          },
          label: 'Loading package $packageName',
          scope: packageName,
          blocksPreview: true,
        );
      } else if (params['gist'] case final String gistId) {
        userErrorMessage =
            'The GitHub Gist could not be loaded. '
            'Please check that the Gist ID "$gistId" in the URL is correct.';
        final loader = GistLoader(gistId: gistId);
        project = await session.taskStatus.runTask(
          TaskKind.loadingCode,
          () => loader.loadGist(session.repository.root),
          scope: gistId,
          blocksPreview: true,
        );
      } else if (params['sample'] case final String sampleId) {
        userErrorMessage = 'The requested sample "$sampleId" could not be loaded.';
        project = await session.taskStatus.runTask(
          TaskKind.loadingCode,
          () => loadSampleProject(
            session.repository.root,
            sampleId: sampleId,
          ),
          label: 'Loading sample $sampleId',
          scope: sampleId,
          blocksPreview: true,
        );
      } else {
        userErrorMessage = 'The default project could not be loaded.';
        project = await session.taskStatus.runTask(
          TaskKind.loadingCode,
          () => loadSampleProject(session.repository.root),
          blocksPreview: true,
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
    } catch (error, stackTrace) {
      if (_isCurrent(session)) {
        session.events.dispatch(
          LogEvent(
            'Project loading failed.',
            level: Level.SEVERE,
            error: error,
            stackTrace: stackTrace,
          ),
        );
        setState(() {
          _workspacePreparationFailure = userErrorMessage;
        });
      }
      return null;
    }
  }

  @override
  Component build(BuildContext context) {
    final session = _session;
    return div(classes: 'app-shell', [
      if (!isEmbedMode || !_isLargeScreen)
        AppBar(
          onCreateNewSnippet: _isInitializingWorkspace || session.repository.dartpad == null
              ? null
              : (example) => resetWorkspace(ProjectSource.example(example.id)),
          onLoadSample: _isInitializingWorkspace || session.repository.dartpad == null
              ? null
              : (example) => resetWorkspace(ProjectSource.example(example.id)),
          isEmbedMode: isEmbedMode,
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
                initialValue: 0.7,
                left: EditorShell(
                  openTabs: session.tabs.openTabs,
                  activeFile: session.tabs.activeFile,
                  fileTree: _buildFileTree(session),
                  editorOverlay: _buildEditorOverlay(session),
                  onSwitchFile: session.tabs.switchFile,
                  onCloseFile: session.tabs.closeFile,
                  bottomPanel: _buildBottomPanel(session),
                  contextMenu: session.contextMenu,
                  isEmbedMode: isEmbedMode,
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
                isEmbedMode: isEmbedMode,
                smallScreenPreviewPanel: _selectedSmallScreenTab == .output ? _buildPreviewPanel(session) : null,
              ),
          ]),
          if (!isEmbedMode)
            Footer(
              taskStatus: session.taskStatus,
              analyzerStatus: session.analyzerStatus,
              statusMessage: session.tabs.errorMessage ?? session.tabs.warningMessage,
              isSmallScreen: !_isLargeScreen,
              currentSdk: _currentSdk,
              onSelectSdk: _isInitializingWorkspace ? null : switchSdk,
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
          activeFile: session.tabs.activeFile,
          logs: session.console.logs,
          onClearConsole: session.console.clear,
          events: session.events,
          contextMenu: session.contextMenu,
          onOpenDiagnostic: (fileName, diagnostic) {
            unawaited(session.diagnostics.openDiagnostic(fileName, diagnostic));
          },
        ),
      ),
    );
  }

  Component _buildEditorOverlay(WorkspaceSession session) {
    return .fragment([
      PubspecEditorActions(
        activeFile: session.tabs.activeFile,
        saveAllFiles: session.tabs.saveAllTabs,
        events: session.events,
        onPubGet: (workspacePath) => session.repository.pubGet(
          path: workspacePath,
          projectRoot: _projectDir,
        ),
        onPubClean: (workspacePath) => session.repository.pubClean(path: workspacePath),
      ),
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

  @override
  void dispose() {
    _resizeSubscription?.cancel();
    _session.preview.removeListener(_onPreviewStateChanged);
    unawaited(_session.dispose(closeWorker: true));
    super.dispose();
  }

  static List<StyleRule> get styles => [
    ...ContextMenu.styles,
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
