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
      onError: errors.add,
    );
    await api.changeEventsReady;
  });
  tearDown(() async {
    await controller.stop();
    await session.dispose();
    expect(errors, isEmpty);
  });

  test('typing alone does not write; normal Save persists the same files sent to the worker', () async {
    await controller.flush();
    final writes = store.writes;
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'void main(){print("unsaved");}';
    await pumpEventQueue();
    await controller.flush();
    expect(store.writes, writes);
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'void main() {}');
    expect(await api.readFileAsText('lib/main.dart'), 'void main() {}');
    expect(tab.hasUnsavedChanges, isTrue);

    await session.tabs.saveAllTabs();
    await api.flush();
    await pumpEventQueue();
    await controller.flush();
    expect(store.writes, writes + 1);
    expect(utf8.decode(store.state!.files['lib/main.dart']!), tab.content);
    expect(await remote.readFileAsText('lib/main.dart'), tab.content);
    expect(tab.hasUnsavedChanges, isFalse);
    expect(store.state!.activeFile, 'lib/main.dart');
    expect(store.state!.query, session.initialProject.request.query);
  });

  test('a snapshot triggered by another file excludes unsaved editor text', () async {
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'unsaved';
    await remote.writeFileFromText('pubspec.lock', 'worker output');
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'void main() {}');
    expect(utf8.decode(store.state!.files['pubspec.lock']!), 'worker output');
    expect(tab.hasUnsavedChanges, isTrue);

    await controller.stop();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'void main() {}');
    expect(tab.content, 'unsaved');
  });

  test('tab metadata is persisted without a file write', () async {
    await api.writeFileFromText('notes.txt', 'notes');
    await pumpEventQueue();
    await controller.flush();
    final writes = store.writes;
    await session.tabs.openWorkspaceFile('notes.txt');
    await controller.flush();
    expect(store.writes, writes + 1);
    expect(store.state!.tabs.map((tab) => tab.path), ['lib/main.dart', 'notes.txt']);
    expect(store.state!.activeFile, 'notes.txt');

    session.tabs.switchFile('lib/main.dart');
    await controller.flush();
    expect(store.state!.activeFile, 'lib/main.dart');
    session.tabs.closeFile('notes.txt');
    await controller.flush();
    expect(store.state!.tabs.map((tab) => tab.path), ['lib/main.dart']);
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
    await pumpEventQueue();
    await controller.flush();
    expect(store.state!.files['assets/image.bin'], [0, 255, 128]);
    expect(store.state!.files, isNot(contains('lib/main.dart')));
  });

  test('stop flushes saved workspace changes before their notifications arrive', () async {
    await controller.flush();
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'latest';
    await tab.save();
    await controller.stop();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'latest');
    final writes = store.writes;
    await api.writeFileFromText('ignored.txt', 'after stop');
    await pumpEventQueue();
    expect(store.writes, writes);
  });
  test('workspace saves during an in-flight commit are written afterwards', () async {
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'first';
    await tab.save();
    await pumpEventQueue();
    final flush = controller.flush();
    await pumpEventQueue();
    tab.editor.text = 'second';
    await tab.save();
    await pumpEventQueue();
    barrier.complete();
    await flush;
    expect(utf8.decode(store.state!.files['lib/main.dart']!), 'second');
    expect(store.writes, 2);
  });

  test('storage failure leaves saved files intact and retries on the next save', () async {
    store.writeError = StateError('quota exceeded');
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'keep me';
    await tab.save();
    await pumpEventQueue();
    await controller.flush();
    expect(errors, hasLength(1));
    expect(tab.content, 'keep me');
    expect(tab.hasUnsavedChanges, isFalse);
    expect(store.writes, 0);
    errors.clear();
    store.writeError = null;
    tab.editor.text = 'retry me';
    await tab.save();
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
      await tab.save();
      await pumpEventQueue();
      store.writeError = StateError('temporary failure');
      await controller.flush();
      expect(errors, hasLength(1));
      errors.clear();
      store.writeError = null;
      await controller.flush();
      expect(utf8.decode(store.state!.files['lib/main.dart']!), 'pending recovery');
      expect(tab.hasUnsavedChanges, isFalse);
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

  test('other tabs can save while local editing and autosave continue', () async {
    await controller.flush();
    final id = controller.projectId!;
    await store.write(id, savedProject(text: 'another tab'));
    await pumpEventQueue();
    expect(errors, isEmpty);
    final tab = session.tabs.activeTab! as WorkspaceCodeMirrorTab;
    tab.editor.text = 'local work';
    await tab.save();
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.entries[id]!.state.files['lib/main.dart']!), 'local work');
    expect(tab.content, 'local work');
  });

  test('maximum delay persists continuous workspace writes instead of waiting for idle', () async {
    await controller.stop();
    controller = WorkspacePersistenceController(
      session: session,
      store: store,
      onError: errors.add,
      debounce: const Duration(seconds: 5),
      maxDelay: const Duration(milliseconds: 40),
    );
    var edits = 0;
    final writing = Timer.periodic(const Duration(milliseconds: 10), (_) {
      unawaited(api.writeFileFromText('lib/main.dart', 'saved ${edits++}'));
    });
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(store.writes, greaterThan(0));
    } finally {
      writing.cancel();
    }
    await pumpEventQueue();
    await controller.flush();
    expect(utf8.decode(store.state!.files['lib/main.dart']!), await api.readFileAsText('lib/main.dart'));
  });
}
