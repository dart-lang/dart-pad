// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import 'features/editor/codemirror/code_mirror_tab.dart';
import 'features/editor/codemirror/code_mirror_tab_adapter.dart';
import 'features/editor/components/editor_shell.dart';
import 'features/editor/view_models/tabs_view_model.dart';
import 'features/shared/app_event_bus.dart';
import 'features/shared/browser_console_observer.dart';
import 'features/shared/events/log_event.dart';
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

  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;

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

      _analyzerSubscription = languageServerClient.analyzerActivityStream.listen(
        (activity) => _logAnalyzerActivity(languageServerClient, activity),
      );

      setState(() {
        loadingStatus = 'Running Pub Get...';
      });

      await _workspaceRepository.pubGet();

      codemirrorAdapter.attachLanguageServerClient(languageServerClient);

      setState(() {
        loadingStatus = 'Analyzing Project...';
      });
    });

    Future(() async {
      await createSampleProject(_workspaceRepository.root);
      await openSampleProject(_tabs.openFile);
    });
  }

  void _logAnalyzerActivity(LanguageServerClient languageServerClient, AnalyzerActivity activity) {
    switch (activity) {
      case AnalyzerStatusActivity(:final isAnalyzing):
        _events.dispatch(
          LogEvent(
            '${DateTime.now().toIso8601String()}: ${isAnalyzing ? 'Analyzer is working…' : 'Analyzer is idle.'}',
          ),
        );
        if (!isAnalyzing && mounted && loadingStatus == 'Analyzing Project...') {
          setState(() {
            loadingStatus = 'Done';
          });
        }
        if (isAnalyzing && mounted && loadingStatus == 'Done') {
          setState(() {
            loadingStatus = 'Analyzing Project...';
          });
        }
      case AnalyzerDiagnosticsActivity(:final path):
        final entries = languageServerClient.allDiagnostics.where((entry) => entry.fileName == path);
        for (final DiagnosticEntry(:diagnostic) in entries) {
          final level = switch (diagnostic.severity) {
            DiagnosticSeverity.error => Level.SEVERE,
            DiagnosticSeverity.warning => Level.WARNING,
            DiagnosticSeverity.info || DiagnosticSeverity.hint => Level.INFO,
          };
          _events.dispatch(
            LogEvent(
              '$path:${diagnostic.line + 1}:${diagnostic.character + 1} '
              '[${diagnostic.severity.label}] ${diagnostic.message}',
              level: level,
            ),
          );
        }
    }
  }

  @override
  Component build(BuildContext context) {
    return ListenableBuilder(
      listenable: _tabs,
      builder: (context) {
        return EditorShell(
          openTabs: _tabs.openTabs,
          activeFile: _tabs.activeFile,
          errorMessage: _tabs.errorMessage,
          onSwitchFile: _tabs.switchFile,
          onCloseFile: _tabs.closeFile,
          bootstrapLabel: loadingStatus,
        );
      },
    );
  }

  @override
  void dispose() {
    _analyzerSubscription?.cancel();
    unawaited(_disposeResources());
    super.dispose();
  }

  Future<void> _disposeResources() async {
    _tabs.dispose();
    _console.dispose();
    await _events.dispose();
  }
}
