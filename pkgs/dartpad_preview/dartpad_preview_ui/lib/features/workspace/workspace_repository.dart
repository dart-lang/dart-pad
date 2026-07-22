import 'package:dartpad/dartpad.dart';
import 'package:dartpad_preview_shared/dartpad_preview_shared.dart';
import 'package:web/web.dart' as web;

import '../editor/sample_project.dart';
import '../shared/app_event_bus.dart';

/// Owns the complete worker-side workspace lifecycle for the transient app.
final class WorkspaceRepository extends WorkspaceController {
  WorkspaceRepository._({
    required this.dartpad,
    required super.workspace,
    required super.languageServer,
    required this.events,
  });

  final DartPad dartpad;
  final AppEventBus events;

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
