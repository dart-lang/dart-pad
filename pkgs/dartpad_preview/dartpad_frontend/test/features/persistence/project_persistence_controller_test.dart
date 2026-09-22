// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/persistence/project_persistence_controller.dart';
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
      await session.dispose();
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
    await controller.stop();

    final replacement = await createSession('replacement session');
    controller.attach(replacement, projectId: controller.projectId);
    await controller.flush();
    expect(store.entries, hasLength(1));
    expect(controller.projectId, id);
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'replacement session');

    // A subsequent fresh project must not accidentally reuse the retained ID.
    await controller.stop();
    controller.attach(await createSession('fresh project'));
    await controller.flush();
    expect(store.entries, hasLength(2));
    expect(controller.projectId, isNot(id));
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'replacement session');
  });

  test('another tab can write without interrupting this session or creating a copy', () async {
    final session = await createSession('my changes');
    controller.attach(session);
    await controller.flush();
    final id = controller.projectId!;
    await store.write(id, savedProject(text: 'their changes'));
    await pumpEventQueue();
    expect(controller.notice, isNull);
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'their changes');

    await session.repository.workspaceResourceApi.writeFileFromText('lib/main.dart', 'my latest changes');
    await pumpEventQueue();
    await controller.flush();
    expect(controller.notice, isNull);
    expect(controller.projectId, id);
    expect(store.entries, hasLength(1));
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'my latest changes');
  });

  test('stopping an unchanged tab preserves a newer save from another tab', () async {
    controller.attach(await createSession('old local version'));
    await controller.flush();
    final id = controller.projectId!;
    await store.write(id, savedProject(text: 'newer other tab version'));
    final writes = store.writes;
    await controller.stop();
    expect(store.writes, writes);
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'newer other tab version');
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

  test('offerRestore sets offer and dismissRestoreOffer clears it without timer', () async {
    controller.offerRestore('test-project');
    expect(controller.restoreOffer, isNotNull);
    expect(controller.restoreOffer!.projectId, 'test-project');

    controller.dismissRestoreOffer();
    expect(controller.restoreOffer, isNull);
  });
}
