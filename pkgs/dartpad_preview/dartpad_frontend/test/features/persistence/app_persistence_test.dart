// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/app.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

import '../../project_fixture.dart';
import '../../worker_fixture.dart';
import 'persistence_fixture.dart';

void main() {
  TestWorker.captureAssetBaseUrl();
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

  App app(String query, {List<TestWorker>? workers}) => App(
    initialUri: Uri.parse(query),
    projectStore: store,
    loadSource: (_) async {
      sourceLoads++;
      return testProjectContents({'lib/main.dart': 'void main() { print("fresh"); }'});
    },
    createRepository: ({required events, required sdk, required taskStatus, localApi, deferWorker = false}) {
      final repository = WorkspaceRepository(
        events: events,
        sdk: sdk,
        taskStatus: taskStatus,
        workspaceResourceApi: localApi!,
        dartpad: workers?[repositories.length].dartpad,
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
  });

  testClient('theme-only query restores the latest entry', (tester) async {
    final latest = await store.create(savedProject(text: 'most recent'));
    tester.pumpComponent(app('?theme=dark'));
    await pumpEventQueue();
    expect(sourceLoads, 0);
    expect(await repositories.single.workspaceResourceApi.readFileAsText('lib/main.dart'), 'most recent');
    expect(store.entries, hasLength(2));
    expect(store.state, same(store.entries[latest.id]!.state));
  });

  testClient('matching URL saves fresh work immediately without blocking', (tester) async {
    final workers = [await TestWorker.start(), await TestWorker.start()];
    for (final worker in workers) {
      addTearDown(worker.dispose);
    }
    tester.pumpComponent(app('?sample=counter', workers: workers));
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(store.entries, hasLength(2));
    expect(web.document.querySelector('dialog'), isNull);
    expect(web.document.querySelector('.app-shell')!.hasAttribute('inert'), isFalse);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('fresh'));

    final freshId = store.entries.keys.singleWhere((id) => id != 'saved');
    await repositories.single.workspaceResourceApi.writeFileFromText('lib/main.dart', 'edited fresh project');
    await pumpEventQueue();
    expect(String.fromCharCodes(store.entries[freshId]!.state.files['lib/main.dart']!), 'edited fresh project');
    expect(store.entries, hasLength(2));
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

  testClient('different query creates a new entry', (tester) async {
    tester.pumpComponent(app('?sample=flame-game'));
    await pumpEventQueue();
    expect(store.entries, hasLength(2));
    expect(String.fromCharCodes(store.state!.files['lib/main.dart']!), contains('fresh'));
    expect(String.fromCharCodes(store.entries['saved']!.state.files['lib/main.dart']!), contains('previous work'));
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

  testClient('failed restore offers Start fresh and retains the failed entry', (tester) async {
    final files = savedProject().files;
    final previous = savedProject(files: {...files, 'lib/./main.dart': files['lib/main.dart']!});
    store = MemoryProjectStore(previous);
    tester.pumpComponent(app(''));
    await pumpEventQueue();
    final failure = web.document.querySelector('.restore-project-failure')!;
    expect(failure.textContent, contains('Restoring your project failed.'));
    expect(store.entries['saved']!.state, same(previous));
    (failure.querySelector('button')! as web.HTMLElement).click();
    await pumpEventQueue();
    expect(sourceLoads, 1);
    expect(web.document.querySelector('.restore-project-failure'), isNull);
    expect(web.document.querySelector('.cm-content')!.textContent, contains('fresh'));
    expect(store.entries['saved']!.state, same(previous));
    expect(store.entries, hasLength(2));
  });

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
}
