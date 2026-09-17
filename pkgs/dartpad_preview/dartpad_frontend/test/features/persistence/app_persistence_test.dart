// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
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

  App app(String query, {Future<Project> Function()? load, Duration offerDuration = const Duration(seconds: 30)}) =>
      App(
        initialUri: Uri.parse(query),
        projectStore: store,
        restoreOfferDuration: offerDuration,
        loadSource: (_) async {
          sourceLoads++;
          return load != null
              ? await load()
              : testProjectContents({'lib/main.dart': 'void main() { print("fresh"); }'});
        },
        createRepository: ({required events, required sdk, required taskStatus, localApi}) {
          final repository = WorkspaceRepository(
            events: events,
            sdk: sdk,
            taskStatus: taskStatus,
            workspaceResourceApi: localApi!,
            workspaceFuture: Completer<Workspace>().future,
          );
          repositories.add(repository);
          return repository;
        },
      );

  testClient('without query restores the latest entry and transfers ownership', (tester) async {
    final latest = await store.create(savedProject(text: 'most recent'), ownerId: 'another-tab');
    tester.pumpComponent(app(''));
    await pumpEventQueue();
    expect(sourceLoads, 0);
    expect(await repositories.single.workspaceResourceApi.readFileAsText('lib/main.dart'), 'most recent');
    expect(await repositories.single.workspaceResourceApi.folderExist('empty'), isTrue);
    expect(store.entries, hasLength(2));
    expect(store.entries[latest.id]!.ownerId, matches(RegExp(r'^[0-9a-f-]{36}$')));
    expect(store.entries[latest.id]!.ownerId, isNot('another-tab'));
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
    expect(restore.textContent, 'Restore last project');
    expect(restore.querySelector('.restore-last-project-timer'), isNotNull);
    expect(restore.getAttribute('style'), contains('--restore-remaining:'));

    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'edited fresh project');
    await pumpEventQueue();
    // Read the latest snapshot at click time, not the copy from startup.
    await store.write('saved', savedProject(text: 'latest previous work'), ownerId: 'previous-tab');
    (restore as web.HTMLElement).click();
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(repositories, hasLength(2));
    expect(web.document.querySelector('.restore-last-project'), isNull);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('latest previous work'));
    expect(String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!), 'edited fresh project');
    expect(store.entries, hasLength(2));
    expect(store.entries['saved']!.ownerId, store.entries[freshId]!.ownerId);
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

  testClient('restore offer expires without replacing previous work', (tester) async {
    tester.pumpComponent(app('?sample=counter', offerDuration: const Duration(milliseconds: 100)));
    await pumpEventQueue();
    expect(web.document.querySelector('.restore-last-project'), isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 150));
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

  for (final useLatest in [true, false]) {
    testClient('ownership conflict pauses editing and resolves with useLatest=$useLatest', (tester) async {
      tester.pumpComponent(app(''));
      await pumpEventQueue();
      final owner = store.entries['saved']!.ownerId;
      await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'my version');
      await pumpEventQueue();
      await store.claim('saved', ownerId: 'new-tab');
      await store.write('saved', savedProject(text: 'new changes'), ownerId: 'new-tab');
      await pumpEventQueue();
      final dialog = web.document.querySelector('#project-conflict-dialog')! as web.HTMLDialogElement;
      expect(dialog.open, isTrue);
      expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isTrue);
      expect(dialog.dispatchEvent(web.Event('cancel', web.EventInit(cancelable: true))), isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), 'new changes');
      (dialog.querySelectorAll('button').item(useLatest ? 0 : 1)! as web.HTMLElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('#project-conflict-dialog'), isNull);
      expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isFalse);
      expect(
        await repositories.last.workspaceResourceApi.readFileAsText('lib/main.dart'),
        useLatest ? 'new changes' : 'my version',
      );
      expect(store.entries, hasLength(useLatest ? 1 : 2));
      expect(store.entries['saved']!.ownerId, useLatest ? owner : 'new-tab');
      if (!useLatest) {
        expect(String.fromCharCodes(store.state!.files['lib/main.dart']!), 'my version');
        expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), 'new changes');
      }
    });
  }

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
    testClient('embed mode bypasses all history and ownership operations: $query', (tester) async {
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
