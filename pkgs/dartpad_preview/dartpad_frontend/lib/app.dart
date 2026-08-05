// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import 'features/bottom_panel/view_models/debug_console_view_model.dart';
import 'features/bottom_panel/view_models/diagnostics_view_model.dart';
import 'features/bottom_panel/views/bottom_panel.dart';
import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/codemirror/code_mirror_tab_adapter.dart';
import 'features/editor/components/editor_shell.dart';
import 'features/editor/components/pubspec_editor_actions.dart';
import 'features/editor/view_models/tabs_view_model.dart';
import 'features/filetree/file_tree_tabs_adapter.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/filetree/file_tree_view_model.dart';
import 'features/preview/view/preview_container.dart';
import 'features/preview/view_models/preview_view_model.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/footer.dart';
import 'features/shared/components/split_panel.dart';
import 'features/shared/events/log_event.dart';
import 'features/shared/events/workspace_event.dart';
import 'features/startup/archive_loader.dart';
import 'features/startup/sample_project.dart';
import 'features/workspace/data/workspace_repository.dart';

/// The deliberately small first production slice of DartPad.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();

  @css
  static List<StyleRule> get styles => AppState.styles;
}

/// Composition root – wires all services and drives the startup lifecycle.
class AppState extends State<App> {
  late final AppEventBus _events;
  late final WorkspaceRepository _workspaceRepository;
  late final TabsViewModel _tabs;
  late final FileTreeViewModel _fileTree;
  late final DiagnosticsViewModel _diagnostics;
  late final DebugConsoleViewModel _debugConsole;
  late final PreviewViewModel _preview;

  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;

  String loadingStatus = 'Loading Workspace...';
  String _projectDir = '';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _events = AppEventBus();

    _debugConsole = DebugConsoleViewModel(events: _events);

    _workspaceRepository = WorkspaceRepository.create(events: _events);

    final codemirrorAdapter = CodeMirrorTabAdapter();

    _tabs = TabsViewModel(
      workspaceResourceApi: _workspaceRepository.workspaceResourceApi,
      adapters: [codemirrorAdapter],
    );

    _fileTree = FileTreeViewModel(
      tabs: FileTreeTabsAdapter(_tabs),
      workspace: _workspaceRepository.workspaceResourceApi,
    );
    _diagnostics = DiagnosticsViewModel(tabs: _tabs);

    _preview = PreviewViewModel(workspaceRepository: _workspaceRepository, eventBus: _events);

    final projectFuture = loadProject();

    _events.on<WorkspaceLoadedEvent>().listen((event) async {
      if (!mounted) {
        return;
      }

      await projectFuture;

      if (!mounted) {
        return;
      }

      setState(() {
        loadingStatus = 'Running Pub Get...';
      });

      try {
        await _workspaceRepository.pubGet(
          path: _projectDir,
          projectRoot: _projectDir,
        );
      } catch (error, stackTrace) {
        _events.dispatch(
          LogEvent(
            'Pub get failed.',
            level: Level.SEVERE,
            error: error,
            stackTrace: stackTrace,
          ),
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        loadingStatus = 'Initializing Analyzer...';
      });

      final languageServer = await event.workspace.startLanguageServer();
      final languageServerClient = LanguageServerClient(
        languageServer: languageServer,
        rootWorkspaceUri: event.workspace.workspaceFolder,
        workspaceChangeEvents: _workspaceRepository.workspaceResourceApi.changeEvents,
        documentEditsHandler: (filePath, edits) async {
          final tab = _tabs.getTab(filePath);
          if (tab != null && tab is CodeMirrorTab) {
            await tab.applyEdits(edits);
          } else {
            final file = _workspaceRepository.root.getFile(filePath);
            await file.writeContent(LanguageServerClient.applyEdits(await file.readContent(), edits));
          }
        },
        displayFileHandler: (filePath) async {
          await _tabs.openFile(filePath);
        },
      );

      _analyzerSubscription = languageServerClient.analyzerActivityStream.listen(
        _updateAnalyzerStatus,
      );

      _fileTree.languageServerClient = languageServerClient;
      _diagnostics.attachLanguageServer(languageServerClient);

      codemirrorAdapter.attachLanguageServerClient(languageServerClient);

      setState(() {
        loadingStatus = 'Analyzing Project...';
      });
    });
  }

  Future<void> loadProject() async {
    final params = Uri.base.queryParameters;

    try {
      if (params case {
        'archive': final String archiveUrlParam,
        'path': final String filePathParam,
      }) {
        setState(() {
          loadingStatus = 'Downloading Archive...';
          _errorMessage = null;
        });
        final archiveUrl = Uri.decodeComponent(archiveUrlParam);
        final filePath = Uri.decodeComponent(filePathParam);
        final loader = ArchiveLoader(archiveUrl: archiveUrl, filePath: filePath);
        final (:projectDir, :targetFilePath) = await loader.loadArchive(_workspaceRepository.root);
        setState(() {
          _projectDir = projectDir;
        });
        _fileTree.focusPath(projectDir);
        if (targetFilePath != null) {
          unawaited(_tabs.openFile(workspaceContext.normalize(targetFilePath)));
        }
      } else if (params case {'package': final String packageName}) {
        setState(() {
          loadingStatus = 'Resolving Package...';
          _errorMessage = null;
        });
        final loader = await ArchiveLoader.forPackage(packageName);
        setState(() {
          loadingStatus = 'Downloading Package...';
        });
        final (:projectDir, :targetFilePath) = await loader.loadArchive(_workspaceRepository.root);
        setState(() {
          _projectDir = projectDir;
        });
        _fileTree.focusPath(projectDir);
        if (targetFilePath != null) {
          unawaited(_tabs.openFile(workspaceContext.normalize(targetFilePath)));
        }
      } else {
        setState(() {
          loadingStatus = 'Creating Sample Project...';
          _errorMessage = null;
        });
        await createSampleProject(_workspaceRepository.root);
        setState(() {
          _projectDir = '';
        });
        _fileTree.focusPath('');
        unawaited(openSampleProject(_tabs.openFile));
      }
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to load project: $error';
      });
    }
  }

  void _updateAnalyzerStatus(AnalyzerActivity activity) {
    if (!mounted || activity is! AnalyzerStatusActivity) {
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
    return ListenableBuilder(
      listenable: _tabs,
      builder: (context) => div(classes: 'app-shell', [
        div(classes: 'app-workspace', [
          SplitPanel(
            left: EditorShell(
              openTabs: _tabs.openTabs,
              activeFile: _tabs.activeFile,
              fileTree: _buildFileTree(),
              editorOverlay: _buildEditorOverlay(),
              onSwitchFile: _tabs.switchFile,
              onCloseFile: _tabs.closeFile,
              bottomPanel: _buildBottomPanel(),
            ),
            right: ListenableBuilder(
              listenable: _preview,
              builder: (context) => PreviewContainer(
                preview: _preview,
                activeFile: _tabs.activeFile,
              ),
            ),
          ),
        ]),
        Footer(
          statusLabel: _errorMessage ?? _tabs.errorMessage ?? _tabs.warningMessage ?? loadingStatus,
        ),
      ]),
    );
  }

  Component _buildBottomPanel() {
    return ListenableBuilder(
      listenable: _debugConsole,
      builder: (context) => ListenableBuilder(
        listenable: _diagnostics,
        builder: (context) => BottomPanel(
          diagnostics: _diagnostics.diagnostics,
          hasMoreDiagnostics: _diagnostics.hasMoreDiagnostics,
          activeFile: _tabs.activeFile,
          logs: _debugConsole.logs,
          onClearDebugConsole: _debugConsole.clear,
          onOpenDiagnostic: (fileName, diagnostic) {
            unawaited(_diagnostics.openDiagnostic(fileName, diagnostic));
          },
        ),
      ),
    );
  }

  Component _buildEditorOverlay() {
    return PubspecEditorActions(
      activeFile: _tabs.activeFile,
      saveAllFiles: _tabs.saveAllTabs,
      events: _events,
      onPubGet: (workspacePath) => _workspaceRepository.pubGet(
        path: workspacePath,
        projectRoot: _projectDir,
      ),
      onPubClean: (workspacePath) => _workspaceRepository.pubClean(path: workspacePath),
    );
  }

  Component _buildFileTree() {
    return ListenableBuilder(
      listenable: _fileTree,
      builder: (context) => FileTreeView(
        state: _fileTree.state,
        actions: _fileTree.actions,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    await _analyzerSubscription?.cancel();
    _debugConsole.dispose();
    _diagnostics.dispose();
    _fileTree.dispose();
    _tabs.dispose();
    await _events.dispose();
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
    css('.app-workspace').styles(
      display: .flex,
      minWidth: .zero,
      minHeight: .zero,
      flex: const Flex(grow: 1, basis: .zero),
    ),
  ];
}
