// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/codemirror/code_mirror_tab.dart';
import 'package:dartpad_frontend/features/persistence/workspace_persistence_controller.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/synced_workspace_resource_api.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import '../../project_fixture.dart';
import 'persistence_fixture.dart';

void main() {
  setUpAll(() async {
    final script = web.document.createElement('script') as web.HTMLScriptElement;
    final loaded = web.EventStreamProviders.loadEvent.forTarget(script).first;
    script.src = 'packages/codemirror_dart/assets/codemirror-dart.bundle.js';
    web.document.head!.appendChild(script);
    await loaded;
  });

  late WorkspaceSession session;
  late SyncedWorkspaceResourceApi api;
  late MemoryWorkspaceResourceApi remote;
  late MemoryProjectStore store;
  late WorkspacePersistenceController controller;
  late List<Object> errors;
  setUp(() async {
    final local = MemoryWorkspaceResourceApi();
    await local.createFolder('lib');
    await local.writeFileFromText('lib/main.dart', 'void main() {}');
    remote = MemoryWorkspaceResourceApi();
    api = SyncedWorkspaceResourceApi(localApi: local, remoteApi: Future.value(remote));
    await api.apiReady;
    final initial = testProject(query: '?sdk=dart&file=lib/main.dart');
    session = WorkspaceSession.create(
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
    await session.openProjectFiles();
    store = MemoryProjectStore(savedProject());
    errors = [];
    controller = WorkspacePersistenceController(
      session: session,
      store: store,
      ownerId: 'this-tab',
      onError: errors.add,
    );
    await api.changeEventsReady;
  });
  tearDown(() async {
    await controller.stop();
    await session.dispose(closeWorker: false);
    expect(errors, isEmpty);
  });

  test('captures current unsaved editor text without formatting or marking it saved', () async {
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'void main(){print("unsaved");}';
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'void main(){print("unsaved");}');
    expect(await api.readFileAsText('lib/main.dart'), 'void main() {}');
    expect(tab.hasUnsavedChanges, isTrue);
    expect(store.state!.activeFile, 'lib/main.dart');
    expect(store.state!.query, session.initialProject.request.query);
    tab.discardUnsavedChanges();
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'void main() {}');
  });

  test('new projects save immediately and include worker output but exclude generated caches', () async {
    await remote.writeFileFromText('pubspec.lock', 'generated lock');
    await remote.createFolder('.dart_tool');
    await remote.writeFileFromText('.dart_tool/package_config.json', '{}');
    session.tabs.switchFile('lib/main.dart');
    await pumpEventQueue();
    await controller.flush();
    expect(store.writes, 1);
    expect(store.entries, hasLength(2));
    expect(utf8.decode(store.entries['saved']!.state.files['lib/main.dart']!), contains('previous work'));
    expect(store.state!.files, contains('pubspec.lock'));
    expect(store.state!.files, isNot(contains('.dart_tool/package_config.json')));
  });

  test('deletes and binary assets survive', () async {
    await api.createFolder('assets');
    await api.writeFileFromBytes('assets/image.bin', Uint8List.fromList([0, 255, 128]));
    await api.deleteFileSystemEntity('lib/main.dart');
    await remote.createFolder('build');
    await remote.writeFileFromText('build/output.js', 'generated');
    await pumpEventQueue();
    await controller.flush();
    expect(store.state!.files['assets/image.bin'], [0, 255, 128]);
    expect(store.state!.files, isNot(contains('lib/main.dart')));
    expect(store.state!.files, isNot(contains('build/output.js')));
  });

  test('stop flushes pending edits before session disposal', () async {
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'latest';
    await pumpEventQueue();
    await controller.stop();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'latest');
    final writes = store.writes;
    await api.writeFileFromText('ignored.txt', 'after stop');
    await pumpEventQueue();
    expect(store.writes, writes);
  });
  test('edits made during an in-flight commit are written afterwards', () async {
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'first';
    await pumpEventQueue();
    final flush = controller.flush();
    await pumpEventQueue();
    tab.editor.text = 'second';
    await pumpEventQueue();
    barrier.complete();
    await flush;
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'second');
    expect(store.writes, 2);
  });

  test('storage failure leaves editor intact and retries on the next edit', () async {
    store.writeError = StateError('quota exceeded');
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'keep me';
    await pumpEventQueue();
    await controller.flush();
    expect(errors, hasLength(1));
    expect(tab.content, 'keep me');
    expect(tab.hasUnsavedChanges, isTrue);
    expect(store.writes, 0);
    errors.clear();
    store.writeError = null;
    tab.editor.text = 'retry me';
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'retry me');
  });

  for (final existingEntry in [false, true]) {
    test('explicit flush retries a failed ${existingEntry ? 'update' : 'create'} without another edit', () async {
      if (existingEntry) {
        await controller.flush();
      }
      final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
      tab.editor.text = 'pending recovery';
      await pumpEventQueue();
      store.writeError = StateError('temporary failure');
      await controller.flush();
      expect(errors, hasLength(1));
      errors.clear();
      store.writeError = null;
      await controller.flush();
      expect(utf8.decode(store.state!.files['lib/main.dart']!), 'pending recovery');
      expect(tab.hasUnsavedChanges, isTrue);
    });
  }

  test('concurrent flushes share one failed attempt rather than retrying in a loop', () async {
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    store.writeError = StateError('quota exceeded');
    final first = controller.flush();
    final second = controller.flush();
    expect(second, same(first));
    barrier.complete();
    await Future.wait([first, second]);
    expect(errors, hasLength(1));
    errors.clear();
    store.writeError = null;
    await controller.flush();
    expect(store.writes, 1);
  });

  test('concurrent stop calls both wait for the final snapshot', () async {
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    final first = controller.stop();
    final second = controller.stop();
    expect(second, same(first));
    var finished = false;
    final observed = second.then((_) => finished = true);
    await pumpEventQueue();
    expect(finished, isFalse);
    expect(store.writes, 0);
    barrier.complete();
    await Future.wait([first, observed]);
    expect(finished, isTrue);
    expect(store.writes, 1);
  });

  test('ownership changes pause saving even without a local edit', () async {
    await controller.flush();
    final id = controller.projectId!;
    await store.claim(id, ownerId: 'another-tab');
    await pumpEventQueue();
    expect(errors, hasLength(1));
    errors.clear();
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'local work';
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'void main() {}');
    expect(tab.content, 'local work');
  });

  test('maximum delay saves during continuous typing instead of waiting for idle', () async {
    await controller.stop();
    controller = WorkspacePersistenceController(
      session: session,
      store: store,
      ownerId: 'this-tab',
      onError: errors.add,
      debounce: const Duration(seconds: 5),
      maxDelay: const Duration(milliseconds: 40),
    );
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    var edits = 0;
    final typing = Timer.periodic(const Duration(milliseconds: 10), (_) {
      tab.editor.text = 'typing ${edits++}';
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(store.writes, greaterThan(0));
    } finally {
      typing.cancel();
    }
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), tab.content);
  });
}
