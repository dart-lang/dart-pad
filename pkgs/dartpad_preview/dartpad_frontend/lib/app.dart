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
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/preview/models/preview_state.dart';
import 'features/preview/view/preview_container.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/app_bar.dart';
import 'features/shared/components/error_dialog.dart';
import 'features/shared/components/footer.dart';
import 'features/shared/components/split_panel.dart';
import 'features/shared/events/log_event.dart';
import 'features/startup/archive_loader.dart';
import 'features/startup/gist_loader.dart';
import 'features/startup/project_loader.dart';
import 'features/startup/sample_project.dart';
import 'features/workspace/data/workspace_repository.dart';
import 'features/workspace/workspace_lifecycle.dart';
import 'features/workspace/workspace_session.dart';

/// Whether the application is running in embed mode (`?embed=true`).
///
/// When `true`, the app bar and footer are hidden and the file tree starts
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

  /// Loads a sample, or the default sample when [sampleId] is omitted.
  const factory ProjectSource.sample([String? sampleId]) = SampleProjectSource;

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

/// A project source that always loads a packaged sample.
final class SampleProjectSource extends ProjectSource {
  const SampleProjectSource([this.sampleId]);

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
  String loadingStatus = 'Loading Workspace...';
  String _projectDir = '';
  String? _errorMessage;

  bool _isLargeScreen = true;
  int _mobileTabIndex = 0;
  StreamSubscription<web.Event>? _resizeSubscription;

  @override
  void initState() {
    super.initState();
    _isLargeScreen = web.window.innerWidth >= minLargeScreenWidth;
    _resizeSubscription = web.EventStreamProviders.resizeEvent.forTarget(web.window).listen((_) {
      _updateScreenSize();
    });

    final events = AppEventBus();
    _session = WorkspaceSession.create(
      WorkspaceRepository.create(events: events),
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
        if (_mobileTabIndex != 1) {
          setState(() {
            _mobileTabIndex = 1;
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

      unawaited(_initializeWorkspaceTools(session, workspace, project));
    } catch (error) {
      if (!_isCurrent(session)) {
        return;
      }
      setState(() {
        _isInitializingWorkspace = false;
        _errorMessage = 'The workspace could not be initialized.';
      });
    }
  }

  Future<void> _initializeWorkspaceTools(
    WorkspaceSession session,
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

      session.attachLanguageServer(
        server: languageServer,
        client: languageServerClient,
        onAnalyzerActivity: (activity) => _updateAnalyzerStatus(session, activity),
      );

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
  void resetWorkspace(ProjectSource source) {
    final oldSession = _session;
    final worker = oldSession.repository.dartpad;
    if (_isInitializingWorkspace || worker == null) {
      return;
    }

    final previousWorkspaceDisposed = Completer<void>();
    final events = AppEventBus();
    final nextSession = WorkspaceSession.create(
      WorkspaceRepository.resetAndCreate(
        events: events,
        worker: worker,
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
      loadingStatus = 'Initializing Workspace...';
      _errorMessage = null;
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

  Future<LoadedProject?> _loadProject(
    WorkspaceSession session, {
    required ProjectSource source,
  }) async {
    final params = source.queryParameters;
    var userErrorMessage = 'The project could not be loaded.';

    try {
      final LoadedProject project;
      if (params case {
        'archive': final String archiveUrlParam,
        'path': final String filePathParam,
      }) {
        userErrorMessage =
            'The project archive could not be downloaded. '
            'Please check that the URL is correct and accessible.';
        _updateLoadingStatus(session, 'Downloading Archive...', clearError: true);
        final archiveUrl = Uri.decodeComponent(archiveUrlParam);
        final filePath = Uri.decodeComponent(filePathParam);
        final loader = ArchiveLoader(archiveUrl: archiveUrl, filePath: filePath);
        project = await loader.loadArchive(session.repository.root);
      } else if (params case {'package': final String packageName}) {
        userErrorMessage =
            'The package "$packageName" could not be resolved from pub.dev. '
            'Please verify the package name in the URL.';
        _updateLoadingStatus(session, 'Resolving Package...', clearError: true);
        final loader = await ArchiveLoader.forPackage(packageName);
        _updateLoadingStatus(session, 'Downloading Package...');
        project = await loader.loadArchive(session.repository.root);
      } else if (params['gist'] case final String gistId) {
        userErrorMessage =
            'The GitHub Gist could not be loaded. '
            'Please check that the Gist ID "$gistId" in the URL is correct.';
        _updateLoadingStatus(session, 'Downloading Gist...', clearError: true);
        final loader = GistLoader(gistId: gistId);
        project = await loader.loadGist(session.repository.root);
      } else if (params['sample'] case final String sampleId) {
        userErrorMessage = 'The requested sample "$sampleId" could not be loaded.';
        _updateLoadingStatus(session, 'Loading Sample...', clearError: true);
        project = await loadSampleProject(
          session.repository.root,
          sampleId: sampleId,
        );
      } else {
        userErrorMessage = 'The default project could not be loaded.';
        _updateLoadingStatus(session, 'Initializing Workspace...', clearError: true);
        project = await loadSampleProject(
          session.repository.root,
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
          _errorMessage = userErrorMessage;
        });
      }
      return null;
    }
  }

  void _updateLoadingStatus(
    WorkspaceSession session,
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
    WorkspaceSession session,
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
      if (!isEmbedMode || !_isLargeScreen)
        AppBar(
          onCreateSample: _isInitializingWorkspace || session.repository.dartpad == null
              ? null
              : (sample) => resetWorkspace(ProjectSource.sample(sample.id)),
          onSelectExample: _isInitializingWorkspace || session.repository.dartpad == null
              ? null
              : (sample) => resetWorkspace(ProjectSource.sample(sample.id)),
          isMobile: !_isLargeScreen,
          isEmbedMode: isEmbedMode,
          selectedTab: _mobileTabIndex,
          onTabSelected: (tab) => setState(() => _mobileTabIndex = tab),
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
                  isEmbedMode: isEmbedMode,
                ),
                right: _buildPreviewPanel(session),
              )
            else ...[
              div(
                classes: 'app-workspace-mobile-pane ${_mobileTabIndex == 0 ? 'active' : 'hidden'}',
                [
                  EditorShell(
                    openTabs: session.tabs.openTabs,
                    activeFile: session.tabs.activeFile,
                    fileTree: _buildFileTree(session),
                    editorOverlay: _buildEditorOverlay(session),
                    onSwitchFile: session.tabs.switchFile,
                    onCloseFile: session.tabs.closeFile,
                    bottomPanel: _buildBottomPanel(session),
                    isEmbedMode: isEmbedMode,
                  ),
                ],
              ),
              div(
                classes: 'app-workspace-mobile-pane ${_mobileTabIndex == 1 ? 'active' : 'hidden'}',
                [
                  _buildPreviewPanel(session),
                ],
              ),
            ],
          ]),
          if (!isEmbedMode)
            Footer(
              statusLabel: session.tabs.errorMessage ?? session.tabs.warningMessage ?? loadingStatus,
              isMobile: !_isLargeScreen,
            ),
        ]),
      ),
      if (_errorMessage case final String message) ErrorDialog(errorMessage: message),
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
          onOpenDiagnostic: (fileName, diagnostic) {
            unawaited(session.diagnostics.openDiagnostic(fileName, diagnostic));
          },
        ),
      ),
    );
  }

  Component _buildEditorOverlay(WorkspaceSession session) {
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

  Component _buildFileTree(WorkspaceSession session) {
    return ListenableBuilder(
      listenable: session.fileTree,
      builder: (context) => FileTreeView(
        state: session.fileTree.state,
        actions: session.fileTree.actions,
      ),
    );
  }

  Component _buildPreviewPanel(WorkspaceSession session) {
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
    _resizeSubscription?.cancel();
    _session.preview.removeListener(_onPreviewStateChanged);
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
    css('.app-workspace-mobile-pane').styles(
      display: .flex,
      width: 100.percent,
      height: 100.percent,
      minWidth: .zero,
      minHeight: .zero,
      flexDirection: .column,
      flex: const Flex(grow: 1, basis: .zero),
    ),
    css('.app-workspace-mobile-pane.hidden').styles(
      display: .none,
    ),
  ];
}
