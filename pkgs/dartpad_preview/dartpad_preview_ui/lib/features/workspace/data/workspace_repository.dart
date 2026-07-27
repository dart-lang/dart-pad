// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:web/web.dart' as web;

import '../../shared/app_event_bus.dart';
import '../../startup/sample_project.dart';

/// Owns the complete worker-side workspace lifecycle for the transient app.
final class WorkspaceRepository extends WorkspaceController {
  WorkspaceRepository._({
    required this.dartpad,
    required super.workspace,
    required super.languageServer,
    required this.events,
  });

  /// The DartPad runtime instance that owns the WASM worker.
  final DartPad dartpad;

  /// Shared event bus for lifecycle and diagnostic logging.
  final AppEventBus events;

  /// Creates a new transient workspace and starts the language server.
  static Future<WorkspaceRepository> create({
    required AppEventBus events,
  }) async {
    DartPad? dartpad;
    Workspace? workspace;
    try {
      events.dispatch(const LogEvent('Starting DartPad worker...'));
      dartpad = await DartPad.create(
        assetBaseUrl: Uri.parse(web.document.baseURI).resolve('dartpad/'),
        sdkLocation: Uri.parse('flutter/'),
      );

      events.dispatch(const LogEvent('Creating transient workspace...'));
      workspace = await dartpad.createWorkspace();
      await createSampleProject(workspace);

      events.dispatch(const LogEvent('Starting analyzer...'));
      final languageServer = await workspace.startLanguageServer();
      final repository = WorkspaceRepository._(
        dartpad: dartpad,
        workspace: workspace,
        languageServer: languageServer,
        events: events,
      );
      await repository.ready;
      events.dispatch(const LogEvent('Workspace watcher ready.'));
      return repository;
    } catch (_) {
      if (workspace != null) {
        try {
          await workspace.dispose();
        } catch (_) {}
      }
      if (dartpad != null) {
        try {
          await dartpad.dispose();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> pubGet() async {
    events.dispatch(const LogEvent('Running pub get...'));
    final result = await workspace.pub(command: 'get');
    events.dispatch(LogEvent('pub get finished.\n${result.log}'));
  }

  Future<void> close() async {
    await super.dispose();
    await dartpad.dispose();
  }
}
