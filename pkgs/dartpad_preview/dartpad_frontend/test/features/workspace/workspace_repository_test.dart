// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:test/test.dart';

final class _Workspace implements WorkspaceResourceApi {
  final Set<String> folders = {''};
  final List<String> deletedPaths = [];

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => const Stream.empty();

  @override
  Future<void> get changeEventsReady => Future.value();

  @override
  Future<bool> folderExist(String uri) async => folders.contains(uri);

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    deletedPaths.add(uri);
    folders.removeWhere((path) => path == uri || path.startsWith('$uri/'));
  }

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Pub Get logs its path and command output in order', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    String? commandPath;

    await runWorkspacePubGet(
      events: events,
      path: 'example/.',
      projectRoot: 'example',
      command: (path) async {
        commandPath = path;
        return 'Resolving dependencies...';
      },
    );
    await pumpEventQueue();

    expect(commandPath, 'example');
    expect(logs.map((event) => event.message), [
      'Running pub get in /',
      'Resolving dependencies...',
    ]);

    await subscription.cancel();
    await events.dispose();
  });

  test('Pub Get propagates command failures after logging its path', () async {
    final events = AppEventBus();
    final logs = <LogEvent>[];
    final subscription = events.on<LogEvent>().listen(logs.add);
    final failure = StateError('pub failed');

    await expectLater(
      runWorkspacePubGet(
        events: events,
        path: '',
        projectRoot: '',
        command: (_) async => throw failure,
      ),
      throwsA(same(failure)),
    );
    await pumpEventQueue();

    expect(logs.map((event) => event.message), ['Running pub get in /']);

    await subscription.cancel();
    await events.dispose();
  });

  test(
    'cleanGeneratedOutput removes build and .dart_tool when present',
    () async {
      final workspace = _Workspace()..folders.addAll({'build', 'build/web', '.dart_tool'});

      await WorkspaceRepository.cleanGeneratedOutput(workspace);

      expect(workspace.deletedPaths, ['build', '.dart_tool']);
      expect(workspace.folders, {''});
    },
  );

  test(
    'cleanGeneratedOutput is a no-op when generated folders are absent',
    () async {
      final workspace = _Workspace();

      await WorkspaceRepository.cleanGeneratedOutput(workspace);

      expect(workspace.deletedPaths, isEmpty);
    },
  );

  test(
    'cleanGeneratedOutput removes output below the active project path',
    () async {
      final workspace = _Workspace()
        ..folders.addAll({
          'examples/counter/build',
          'examples/counter/.dart_tool',
          'build',
          '.dart_tool',
        });

      await WorkspaceRepository.cleanGeneratedOutput(
        workspace,
        path: 'examples/counter',
      );

      expect(workspace.deletedPaths, [
        'examples/counter/build',
        'examples/counter/.dart_tool',
      ]);
      expect(workspace.folders, containsAll({'build', '.dart_tool'}));
    },
  );
}
