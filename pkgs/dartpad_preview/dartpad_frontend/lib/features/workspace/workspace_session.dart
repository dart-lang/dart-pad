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
import '../editor/view_models/tabs_view_model.dart';
import '../filetree/file_tree_tabs_adapter.dart';
import '../filetree/file_tree_view_model.dart';
import '../preview/view_models/preview_view_model.dart';
import '../shared/app_event_bus.dart';
import 'data/workspace_repository.dart';

/// Owns every resource whose lifetime is tied to one worker workspace.
final class WorkspaceSession {
  WorkspaceSession._({
    required this.events,
    required this.repository,
    required this.console,
    required this.tabs,
    required this.fileTree,
    required this.diagnostics,
    required this.preview,
    required this._codemirrorAdapter,
  });

  factory WorkspaceSession.create(WorkspaceRepository repository) {
    final codemirrorAdapter = CodeMirrorTabAdapter();
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
    );

    return WorkspaceSession._(
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

  final AppEventBus events;
  final WorkspaceRepository repository;
  final ConsoleViewModel console;
  final TabsViewModel tabs;
  final FileTreeViewModel fileTree;
  final DiagnosticsViewModel diagnostics;
  final PreviewViewModel preview;
  final CodeMirrorTabAdapter _codemirrorAdapter;

  LanguageServer? _languageServer;
  LanguageServerClient? _languageServerClient;
  StreamSubscription<AnalyzerActivity>? _analyzerSubscription;
  bool _disposed = false;

  /// Attaches language-server resources to this session's consumers.
  void attachLanguageServer({
    required LanguageServer server,
    required LanguageServerClient client,
    required void Function(AnalyzerActivity activity) onAnalyzerActivity,
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
      onAnalyzerActivity,
    );
    fileTree.languageServerClient = client;
    diagnostics.attachLanguageServer(client);
    _codemirrorAdapter.attachLanguageServerClient(client);
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

    await _safeAwait(
      closeWorker ? repository.close() : repository.closeWorkspaceOnly(),
    );
    await _safeAwait(events.dispose());
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
