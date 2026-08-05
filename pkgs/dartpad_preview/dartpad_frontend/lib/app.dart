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
import 'features/shared/app_event_bus.dart';
import 'features/shared/components/footer.dart';
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

  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;

  String loadingStatus = 'Loading Workspace...';
  String _projectDir = '';

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

    if (params case {
      'archive': final String archiveUrlParam,
      'path': final String filePathParam,
    }) {
      final archiveUrl = Uri.decodeComponent(archiveUrlParam);
      final filePath = Uri.decodeComponent(filePathParam);
      final loader = ArchiveLoader(archiveUrl: archiveUrl, filePath: filePath);
      final projectDir = await loader.loadArchive(_workspaceRepository.root);
      setState(() {
        _projectDir = projectDir;
      });
      _fileTree.focusPath(projectDir);
      unawaited(_tabs.openFile(workspaceContext.normalize(filePath)));
    } else {
      await createSampleProject(_workspaceRepository.root);
      setState(() {
        _projectDir = '';
      });
      _fileTree.focusPath('');
      unawaited(openSampleProject(_tabs.openFile));
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
          EditorShell(
            openTabs: _tabs.openTabs,
            activeFile: _tabs.activeFile,
            fileTree: _buildFileTree(),
            editorOverlay: _buildEditorOverlay(),
            onSwitchFile: _tabs.switchFile,
            onCloseFile: _tabs.closeFile,
            bottomPanel: _buildBottomPanel(),
          ),
        ]),
        Footer(
          statusLabel: _tabs.errorMessage ?? _tabs.warningMessage ?? loadingStatus,
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
