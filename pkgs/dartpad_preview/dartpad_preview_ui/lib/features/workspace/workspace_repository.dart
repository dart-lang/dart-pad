// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:web/web.dart' as web;

import '../editor/sample_project.dart';
import '../shared/app_event_bus.dart';

/// Owns the complete worker-side workspace lifecycle for the transient app.
///
/// - [dartpad]: the DartPad runtime instance that owns the WASM worker.
/// - [events]: shared event bus for lifecycle and diagnostic logging.
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

  /// Creates a new transient workspace, writes the sample project files,
  /// and starts the language server.
  ///
  /// - [events]: event bus used for progress logging.
  /// - [readLatestMainSource]: called at the last possible moment to capture
  ///   any edits made while the worker was loading.
  static Future<WorkspaceRepository> create({
    required AppEventBus events,
    required String Function() readLatestMainSource,
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
      await workspace.createFolder('lib');
      await workspace.writeFileFromText('pubspec.yaml', samplePubspec);
      // Read at the last possible moment: edits made during worker startup win.
      await workspace.writeFileFromText('lib/main.dart', readLatestMainSource());

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
