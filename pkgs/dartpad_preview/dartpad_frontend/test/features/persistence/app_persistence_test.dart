// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/editor/codemirror/code_mirror_tab.dart';
import 'package:dartpad_frontend/features/editor/components/editor_shell.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/workspace/data/synced_workspace_resource_api.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
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

  late MemoryProjectStore store;
  late List<WorkspaceRepository> repositories;
  late int sourceLoads;
  setUp(() {
    store = MemoryProjectStore(savedProject());
    repositories = [];
    sourceLoads = 0;
  });

  App app(
    String query, {
    Future<Project> Function()? load,
    WorkspaceResourceApi Function(WorkspaceResourceApi)? wrapWorkspace,
  }) => App(
    initialUri: Uri.parse(query),
    projectStore: store,
    loadSource: (_) async {
      sourceLoads++;
      return load != null ? await load() : testProjectContents({'lib/main.dart': 'void main() { print("fresh"); }'});
    },
    createRepository: ({required events, required sdk, required taskStatus, localApi}) {
      final repository = WorkspaceRepository(
        events: events,
        sdk: sdk,
        taskStatus: taskStatus,
        workspaceResourceApi: wrapWorkspace?.call(localApi!) ?? localApi!,
        workspaceFuture: Completer<Workspace>().future,
      );
      repositories.add(repository);
      return repository;
    },
  );

  testClient('without query restores the latest entry', (tester) async {
    final latest = await store.create(savedProject(text: 'most recent'));
    tester.pumpComponent(app(''));
    await pumpEventQueue();
    expect(sourceLoads, 0);
    expect(await repositories.single.workspaceResourceApi.readFileAsText('lib/main.dart'), 'most recent');
    expect(await repositories.single.workspaceResourceApi.folderExist('empty'), isTrue);
    expect(store.entries, hasLength(2));
    expect(store.state, same(store.entries[latest.id]!.state));
    expect(web.document.querySelector('.restore-last-project'), isNull);
  });

  testClient('matching URL saves fresh work immediately and offers a nonblocking restore', (tester) async {
    tester.pumpComponent(app('?sample=counter'));
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(store.entries, hasLength(2));
    expect(web.document.querySelector('dialog'), isNull);
    expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isFalse);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('fresh'));
    final restore = web.document.querySelector('.app-bar-left .restore-last-project')!;
    expect(restore.textContent, contains('Restore project'));
    expect(restore.querySelector('.restore-last-project-timer'), isNull);
    expect(restore.querySelector('.restore-last-project-cancel'), isNotNull);
    final dismiss = restore.querySelector('.restore-last-project-dismiss')!;
    expect(dismiss.getAttribute('title'), 'Dismiss');
    expect(dismiss.textContent, 'close');

    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'edited fresh project');
    await pumpEventQueue();
    // Read the latest snapshot at click time, not the copy from startup.
    await store.write('saved', savedProject(text: 'latest previous work'));
    (restore as web.HTMLElement).click();
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(repositories, hasLength(2));
    expect(web.document.querySelector('.restore-last-project'), isNull);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('latest previous work'));
    expect(String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!), 'edited fresh project');
    expect(store.entries, hasLength(2));
  });

  testClient('restore waits for an already running editor save before stopping persistence', (tester) async {
    final workspaces = <_DelayedSaveWorkspace>[];
    tester.pumpComponent(
      app(
        '?sample=counter',
        wrapWorkspace: (local) {
          final workspace = _DelayedSaveWorkspace(local);
          workspaces.add(workspace);
          return workspace;
        },
      ),
    );
    await pumpEventQueue();
    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    final shell = find.byType(EditorShell).evaluate().single.component as EditorShell;
    final tab = shell.openTabs!.single as WorkspaceCodeMirrorTab;
    final gate = Completer<void>();
    workspaces.single.writeGate = gate.future;
    tab.editor.text = 'void main() { print("saved before restore"); }';
    // Blur uses this same callback; the normal save is still pending when clicked.
    tab.onSaveAll();
    await workspaces.single.writeStarted.future;
    final restore = web.document.querySelector('.restore-last-project')!;
    (restore as web.HTMLElement).click();
    try {
      await pumpEventQueue();
      expect(repositories, hasLength(1));
      expect(tab.hasUnsavedChanges, isTrue);
    } finally {
      gate.complete();
    }
    await pumpEventQueue();
    expect(repositories, hasLength(2));
    expect(
      String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!),
      'void main() { print("saved before restore"); }',
    );
    expect(web.document.querySelector('.cm-content')!.textContent, contains('previous work'));
  });

  testClient('failed editor save keeps the current project and allows retrying restore', (tester) async {
    final workspaces = <_DelayedSaveWorkspace>[];
    tester.pumpComponent(
      app(
        '?sample=counter',
        wrapWorkspace: (local) {
          final workspace = _DelayedSaveWorkspace(local);
          workspaces.add(workspace);
          return workspace;
        },
      ),
    );
    await pumpEventQueue();
    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    final shell = find.byType(EditorShell).evaluate().single.component as EditorShell;
    final tab = shell.openTabs!.single as WorkspaceCodeMirrorTab;
    tab.editor.text = 'void main() { print("keep this edit"); }';
    workspaces.single.writeError = StateError('temporary save failure');
    (web.document.querySelector('.restore-last-project')! as web.HTMLElement).click();
    await pumpEventQueue();
    expect(repositories, hasLength(1));
    expect(tab.hasUnsavedChanges, isTrue);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('keep this edit'));

    workspaces.single.writeError = null;
    (web.document.querySelector('.restore-last-project')! as web.HTMLElement).click();
    await pumpEventQueue();
    expect(repositories, hasLength(2));
    expect(
      String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!),
      'void main() { print("keep this edit"); }',
    );
  });

  testClient('disposing during a restore waits for the previous session to finish saving', (tester) async {
    tester.pumpComponent(app('?sample=counter'));
    await pumpEventQueue();
    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    final barrier = Completer<void>();
    store.writeBarrier = barrier.future;
    await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'last edit');
    await pumpEventQueue();
    (web.document.querySelector('.restore-last-project')! as web.HTMLElement).click();
    await pumpEventQueue();
    tester.binding.detachRootComponent();
    await pumpEventQueue();
    expect(store.closes, 0);
    expect(await repositories.single.workspaceResourceApi.fileExist('lib/main.dart'), isTrue);
    barrier.complete();
    await store.closed.future.timeout(const Duration(seconds: 3));
    expect(store.closes, 1);
    expect(repositories, hasLength(1));
    expect(String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!), 'last edit');
  });

  testClient('cleanup errors are logged rather than escaping after unmount', (tester) async {
    final records = <LogRecord>[];
    final subscription = Logger('App').onRecord.listen(records.add);
    addTearDown(subscription.cancel);
    tester.pumpComponent(app('?sample=counter'));
    await pumpEventQueue();
    final failure = StateError('close failed');
    store.closeError = failure;
    tester.binding.detachRootComponent();
    await store.closed.future.timeout(const Duration(seconds: 3));
    await pumpEventQueue();
    expect(store.closes, 1);
    expect(records.where((record) => identical(record.error, failure)).single.message, 'App cleanup failed.');
  });

  testClient('restore offer does not expire with time', (tester) async {
    tester.pumpComponent(app('?sample=counter'));
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
  });

  testClient('canceling restore offer dismisses button without replacing previous work', (tester) async {
    tester.pumpComponent(app('?sample=counter'));
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
    final cancel = web.document.querySelector('.restore-last-project-cancel')! as web.HTMLElement;
    cancel.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNull);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('fresh'));
    expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), contains('previous work'));
    expect(store.entries, hasLength(2));
  });

  testClient('different query creates a new entry without a restore offer', (tester) async {
    tester.pumpComponent(app('?sample=flame-game'));
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNull);
    expect(store.entries, hasLength(2));
    expect(String.fromCharCodes(store.state!.files['lib/main.dart']!), contains('fresh'));
    expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), contains('previous work'));
  });

  testClient('matching compares decoded query options independent of key order', (tester) async {
    store = MemoryProjectStore(savedProject(query: '?sample=counter&file=lib/main.dart'));
    tester.pumpComponent(app('?file=lib/main.dart&sample=counter'));
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
  });

  testClient('failed URL source still offers restoring matching saved work', (tester) async {
    tester.pumpComponent(app('?sample=counter', load: () async => throw StateError('offline')));
    await pumpEventQueue();
    expect(repositories, isEmpty);
    final restore = web.document.querySelector('.restore-last-project')! as web.HTMLElement;
    restore.click();
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('previous work'));
    expect(store.entries, hasLength(1));
  });

  testClient('unavailable storage loads the source and pauses local saving', (tester) async {
    store.readError = StateError('storage denied');
    tester.pumpComponent(app(''));
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(repositories, hasLength(1));
    expect(web.document.querySelector('.persistence-notice')!.textContent, contains('could not be loaded'));
    expect(store.writes, 0);
  });

  testClient('another tab saving leaves editing enabled and the last autosave wins', (tester) async {
    tester.pumpComponent(app(''));
    await pumpEventQueue();
    await store.write('saved', savedProject(text: 'other tab'));
    web.document.dispatchEvent(web.Event('visibilitychange'));
    await pumpEventQueue();
    expect(web.document.querySelector('dialog'), isNull);
    expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isFalse);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('previous work'));

    await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'my latest edit');
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), 'my latest edit');
    expect(store.entries, hasLength(1));
    expect(repositories, hasLength(1));
    expect(web.document.querySelector('dialog'), isNull);
    expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isFalse);
  });

  for (final query in ['', '?sample=counter']) {
    testClient('failed restore offers Start fresh and retains the failed entry: $query', (tester) async {
      final files = savedProject().files;
      final previous = savedProject(files: {...files, 'lib/./main.dart': files['lib/main.dart']!});
      store = MemoryProjectStore(previous);
      tester.pumpComponent(app(query));
      await pumpEventQueue();
      if (query.isNotEmpty) {
        (web.document.querySelector('.restore-last-project')! as web.HTMLElement).click();
        await pumpEventQueue();
      }
      final failure = web.document.querySelector('.restore-project-failure')!;
      expect(failure.textContent, contains('Restoring your project failed.'));
      expect(store.entries['saved']!.state, same(previous));
      (failure.querySelector('button')! as web.HTMLElement).click();
      await pumpEventQueue();
      expect(sourceLoads, query.isEmpty ? 1 : 2);
      expect(web.document.querySelector('.restore-project-failure'), isNull);
      expect(web.document.querySelector('.restore-last-project'), isNull);
      expect(web.document.querySelector('.cm-content')!.textContent, contains('fresh'));
      expect(store.entries['saved']!.state, same(previous));
      expect(store.entries, hasLength(query.isEmpty ? 2 : 3));
    });
  }

  for (final query in ['?embed=true', '?sample=counter&embed=true']) {
    testClient('embed mode bypasses all history operations: $query', (tester) async {
      final previous = savedProject(query: query);
      store = MemoryProjectStore(previous);
      tester.pumpComponent(app(query));
      await pumpEventQueue();
      expect(sourceLoads, 1);
      expect(repositories, hasLength(1));
      expect(store.reads, 0);
      expect(web.document.querySelector('.app-bar'), isNull);
      expect(web.document.querySelector('.restore-last-project'), isNull);
      expect(web.document.querySelector('dialog'), isNull);
      await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'edited in embed');
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      expect(store.writes, 0);
      expect(store.state, same(previous));
      expect(store.closes, 0);
    });
  }

  testClient('embed=false retains normal history behavior', (tester) async {
    store = MemoryProjectStore(savedProject(query: '?sample=counter&embed=false'));
    tester.pumpComponent(app('?sample=counter&embed=false'));
    await pumpEventQueue();
    expect(store.entries, hasLength(2));
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
  });
}

/// Holds a normal editor save before it reaches the local filesystem.
final class _DelayedSaveWorkspace extends SyncedWorkspaceResourceApi {
  _DelayedSaveWorkspace(WorkspaceResourceApi local)
    : super(localApi: local, remoteApi: Completer<WorkspaceResourceApi>().future);

  Future<void>? writeGate;
  Object? writeError;
  final writeStarted = Completer<void>();

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    if (writeGate case final gate?) {
      if (!writeStarted.isCompleted) {
        writeStarted.complete();
      }
      await gate;
    }
    if (writeError case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    await super.writeFileFromText(uri, content);
  }
}
