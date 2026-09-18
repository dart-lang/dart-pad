// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/persistence/project_persistence_controller.dart';
import 'package:dartpad_frontend/features/persistence/project_persistence_state.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:test/test.dart';

import '../../project_fixture.dart';
import 'persistence_fixture.dart';

void main() {
  late MemoryProjectStore store;
  late ProjectPersistenceController controller;
  late List<WorkspaceSession> sessions;

  setUp(() {
    store = MemoryProjectStore();
    sessions = [];
    controller = ProjectPersistenceController(enabled: true, store: store, restoreProject: (_) async {});
  });

  tearDown(() async {
    controller.dispose();
    await controller.closed;
    for (final session in sessions) {
      await session.dispose(closeWorker: true);
    }
  });

  Future<WorkspaceSession> createSession(String content) async {
    final api = MemoryWorkspaceResourceApi();
    await api.createFolder('lib');
    await api.writeFileFromText('lib/main.dart', content);
    final initial = testProject(query: '?sdk=dart&file=lib/main.dart');
    final session = WorkspaceSession.create(
      WorkspaceRepository(
        events: AppEventBus(),
        taskStatus: TaskStatusController(),
        workspaceResourceApi: api,
        sdk: initial.sdk,
        workspaceFuture: Completer<Workspace>().future,
      ),
      initialProject: initial,
      initialMode: initial.mode,
    );
    sessions.add(session);
    return session;
  }

  test('reattaching a replacement session can retain the same history entry', () async {
    final previous = await createSession('previous session');
    controller.attach(previous);
    await controller.flush();
    final id = controller.projectId!;
    final owner = store.entries[id]!.ownerId;
    await controller.stop();

    final replacement = await createSession('replacement session');
    controller.attach(replacement, projectId: controller.projectId);
    await controller.flush();
    expect(store.entries, hasLength(1));
    expect(controller.projectId, id);
    expect(store.entries[id]!.ownerId, owner);
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'replacement session');

    // A subsequent fresh project must not accidentally reuse the retained ID.
    await controller.stop();
    controller.attach(await createSession('fresh project'));
    await controller.flush();
    expect(store.entries, hasLength(2));
    expect(controller.projectId, isNot(id));
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'replacement session');
  });

  test('failed Keep my version keeps the conflict pending and can be retried', () async {
    controller.attach(await createSession('my changes'));
    await controller.flush();
    final id = controller.projectId!;
    await store.claim(id, ownerId: 'another-tab');
    await store.write(id, savedProject(text: 'their changes'), ownerId: 'another-tab');
    await pumpEventQueue();
    expect(controller.conflict, ProjectOwnershipConflict.awaitingChoice);

    store.writeError = StateError('temporarily unavailable');
    await controller.resolveConflict(useLatest: false);
    expect(controller.conflict, ProjectOwnershipConflict.awaitingChoice);
    expect(controller.notice, isA<ProjectSaveFailed>());
    expect(store.entries, hasLength(1));

    store.writeError = null;
    await controller.resolveConflict(useLatest: false);
    expect(controller.hasConflict, isFalse);
    expect(store.entries, hasLength(2));
    expect(utf8.decode(store.entries[controller.projectId]!.state.files['lib/main.dart']!), 'my changes');
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'their changes');
    expect(store.entries[id]!.ownerId, 'another-tab');
  });

  test('disposal waits for an existing stop before closing the store exactly once', () async {
    controller.attach(await createSession('pending save'));
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    final stopping = controller.stop();
    expect(controller.stop(), same(stopping));
    controller.dispose();
    final closed = controller.closed;
    controller.dispose();
    expect(controller.closed, same(closed));
    await pumpEventQueue();
    expect(store.closes, 0);

    barrier.complete();
    await closed;
    expect(store.closes, 1);
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'pending save');
  });
}
