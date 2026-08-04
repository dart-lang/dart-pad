// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';

import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/codemirror/code_mirror_tab_adapter.dart';
import 'features/editor/components/editor_host.dart';
import 'features/editor/view_models/editor_host_view_model.dart';
import 'features/editor/view_models/tabs_view_model.dart';
import 'features/filetree/file_tree_tabs_adapter.dart';
import 'features/filetree/file_tree_view.dart';
import 'features/filetree/file_tree_view_model.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/browser_console_observer.dart';
import 'features/shared/events/workspace_event.dart';
import 'features/startup/sample_project.dart';
import 'features/workspace/data/workspace_repository.dart';

/// The deliberately small first production slice of DartPad.
class App extends StatefulComponent {
  const App({super.key});

  @override
  State<App> createState() => AppState();
}

/// Composition root – wires all services and drives the startup lifecycle.
class AppState extends State<App> {
  late final AppEventBus _events;
  late final WorkspaceRepository _workspaceRepository;
  late final BrowserConsoleObserver _console;
  late final TabsViewModel _tabs;
  late final FileTreeViewModel _fileTree;
  late final EditorHostViewModel _editorHost;

  String loadingStatus = 'Loading Workspace...';

  @override
  void initState() {
    super.initState();
    _events = AppEventBus();

    _workspaceRepository = WorkspaceRepository.create(events: _events);

    final codemirrorAdapter = CodeMirrorTabAdapter();

    _tabs = TabsViewModel(
      events: _events,
      workspaceResourceApi: _workspaceRepository.workspaceResourceApi,
      adapters: [codemirrorAdapter],
    );
    _fileTree = FileTreeViewModel(
      tabs: FileTreeTabsAdapter(_tabs),
      workspace: _workspaceRepository.workspaceResourceApi,
      events: _events,
    );
    _editorHost = EditorHostViewModel(tabs: _tabs);

    _console = BrowserConsoleObserver(_events);

    _events.on<WorkspaceLoadedEvent>().listen((event) async {
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

      _fileTree.languageServerClient = languageServerClient;
      _editorHost.attachLanguageServer(languageServerClient);

      setState(() {
        loadingStatus = 'Running Pub Get...';
      });

      await _workspaceRepository.pubGet();

      codemirrorAdapter.attachLanguageServerClient(languageServerClient);

      setState(() {
        loadingStatus = '';
      });
    });

    Future(() async {
      await createSampleProject(_workspaceRepository.root);
      await openSampleProject(_tabs.openFile);
    });
  }

  @override
  Component build(BuildContext context) {
    return EditorHost(
      tabs: _tabs,
      editorHostViewModel: _editorHost,
      fileTree: _buildFileTree(),
      bootstrapLabel: loadingStatus,
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
    _editorHost.dispose();
    _fileTree.dispose();
    _tabs.dispose();
    _console.dispose();
    await _events.dispose();
  }
}
