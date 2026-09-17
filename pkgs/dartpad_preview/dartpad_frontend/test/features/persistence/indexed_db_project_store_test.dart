// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:dartpad_frontend/features/persistence/indexed_db_project_store.dart';
import 'package:dartpad_frontend/features/persistence/persisted_project_state.dart';
import 'package:dartpad_frontend/features/persistence/project_store.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

import 'persistence_fixture.dart';

void main() {
  var sequence = 0;
  late IndexedDbProjectStore store;
  late String name;
  setUp(() {
    name = 'persistence-test-${DateTime.now().microsecondsSinceEpoch}-${sequence++}';
    store = IndexedDbProjectStore(databaseName: name);
  });
  tearDown(() => store.close());

  test('persists binary files, metadata and empty folders across connections', () async {
    expect(await store.list(), isEmpty);
    final state = savedProject(
      files: {
        'assets/image.bin': Uint8List.fromList([0, 255, 128, 10]),
      },
    );
    final saved = await store.create(state, ownerId: 'tab-a');
    final reopened = IndexedDbProjectStore(databaseName: name);
    addTearDown(reopened.close);
    final restored = (await reopened.read(saved.id))!;
    expect(restored.state.files['assets/image.bin'], [0, 255, 128, 10]);
    expect(restored.state.query, state.query);
    expect(restored.state.folders, contains('empty'));
    expect(restored.state.tabs.single.path, state.tabs.single.path);
    expect(restored.state.activeFile, state.activeFile);
    expect(restored.state.sdk.dartVersion, state.sdk.dartVersion);
    expect(restored.ownerId, 'tab-a');
  });

  test('updates and removes files within one entry while retaining other projects', () async {
    final first = await store.create(
      savedProject(
        files: {
          'old.txt': Uint8List.fromList([1]),
        },
      ),
      ownerId: 'tab-a',
    );
    final second = await store.create(savedProject(), ownerId: 'tab-b');
    await store.write(
      first.id,
      savedProject(
        files: {
          'new.txt': Uint8List.fromList([2]),
        },
      ),
      ownerId: 'tab-a',
    );
    final history = await store.list();
    expect(history.map((entry) => entry.id), [first.id, second.id]);
    expect(history.first.state.files.keys, ['new.txt']);
    expect(history.last.state.files, contains('lib/main.dart'));
  });

  test('ownership is transferred atomically and old owners cannot overwrite files', () async {
    final saved = await store.create(savedProject(), ownerId: 'tab-a');
    final second = IndexedDbProjectStore(databaseName: name);
    addTearDown(second.close);
    await store.write(saved.id, savedProject(text: 'newer'), ownerId: 'tab-a');
    final claimed = await second.claim(saved.id, ownerId: 'tab-b');
    expect(String.fromCharCodes(claimed.state.files['lib/main.dart']!), 'newer');
    expect(claimed.ownerId, 'tab-b');
    await expectLater(
      store.write(saved.id, savedProject(text: 'stale'), ownerId: 'tab-a'),
      throwsA(isA<ProjectStoreConflict>()),
    );
    await second.write(saved.id, savedProject(text: 'new owner'), ownerId: 'tab-b');
    expect(String.fromCharCodes((await store.read(saved.id))!.state.files['lib/main.dart']!), 'new owner');
  });

  test('keeps the ten most recently updated entries and rejects evicted writers', () async {
    final ids = <String>[];
    for (var i = 0; i < 10; i++) {
      ids.add((await store.create(savedProject(text: 'project $i'), ownerId: 'tab-$i')).id);
    }
    await store.write(ids.first, savedProject(text: 'recent edit'), ownerId: 'tab-0');
    final newest = await store.create(savedProject(), ownerId: 'tab-10');
    final history = await store.list();
    expect(history, hasLength(10));
    expect(history.first.id, newest.id);
    expect(history[1].id, ids.first);
    expect(await store.read(ids[1]), isNull);
    await expectLater(store.write(ids[1], savedProject(), ownerId: 'tab-1'), throwsA(isA<ProjectStoreConflict>()));
  });

  test('notifies other tabs of ownership changes without waiting for an edit', () async {
    final saved = await store.create(savedProject(), ownerId: 'tab-a');
    final second = IndexedDbProjectStore(databaseName: name);
    addTearDown(second.close);
    final changed = store.changes.firstWhere((id) => id == saved.id);
    await second.claim(saved.id, ownerId: 'tab-b');
    expect(await changed.timeout(const Duration(seconds: 2)), saved.id);
  });

  test('concurrent creators preserve both projects', () async {
    final second = IndexedDbProjectStore(databaseName: name);
    addTearDown(second.close);
    final created = await Future.wait([
      store.create(savedProject(text: 'A'), ownerId: 'tab-a'),
      second.create(savedProject(text: 'B'), ownerId: 'tab-b'),
    ]);
    expect(created[0].id, isNot(created[1].id));
    expect(await store.list(), hasLength(2));
  });

  test('retries opening after a blocked request times out', () async {
    final opened = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(name);
    request.onupgradeneeded = ((web.Event event) {
      (request.result as web.IDBDatabase).createObjectStore('projects');
    }).toJS;
    request.onsuccess = ((web.Event event) => opened.complete(request.result as web.IDBDatabase)).toJS;
    final blocker = await opened.future;
    // JS interop methods cannot be torn off.
    // ignore: unnecessary_lambdas
    addTearDown(() => blocker.close());
    // A pending deletion queues subsequent opens until this connection closes.
    final blocked = Completer<void>();
    final deleted = Completer<void>();
    final deletion = web.window.indexedDB.deleteDatabase(name);
    deletion.onblocked = ((web.Event event) => blocked.complete()).toJS;
    deletion.onsuccess = ((web.Event event) => deleted.complete()).toJS;
    await blocked.future;
    await expectLater(store.list(), throwsA(isA<TimeoutException>()));
    final retry = store.list();
    blocker.close();
    await deleted.future;
    expect(await retry, isEmpty);
    final saved = await store.create(savedProject(), ownerId: 'tab-a');
    expect((await store.read(saved.id))!.ownerId, 'tab-a');
  });

  test('closed storage cannot reopen a database', () async {
    store.close();
    await expectLater(store.list(), throwsStateError);
  });

  test('metadata round-trips through typed JSON without dropping invalid fields', () {
    final original = savedProject();
    final metadata = jsonDecode(jsonEncode(original.metadata())) as Map<String, Object?>;
    final restored = PersistedProjectState.decode(metadata, original.files);
    expect(restored.query, original.query);
    expect(restored.tabs.single.path, original.tabs.single.path);
    expect(restored.sdk, original.sdk);
    for (final malformed in <Map<String, Object?>>[
      {
        ...metadata,
        'tabs': [metadata['tabs'], 123],
      },
      {
        ...metadata,
        'folders': ['lib', 123],
      },
      {
        ...metadata,
        'query': {
          'sample': ['counter', 123],
        },
      },
      {
        ...metadata,
        'sdk': {'id': 123},
      },
    ]) {
      expect(() => PersistedProjectState.decode(malformed, original.files), throwsA(isA<TypeError>()));
    }
  });

  test('query equality preserves repeated value order and includes unknown options', () {
    final state = savedProject(query: '?sample=counter&file=a&file=b&embed=true');
    expect(state.matchesQuery(Uri.parse('?embed=true&file=a&sample=counter&file=b').queryParametersAll), isTrue);
    expect(state.matchesQuery(Uri.parse('?sample=counter&file=b&file=a&embed=true').queryParametersAll), isFalse);
    expect(state.matchesQuery(Uri.parse('?sample=counter&file=a&file=b').queryParametersAll), isFalse);
    expect(savedProject(query: '?id=a%20b').matchesQuery(Uri.parse('?id=a+b').queryParametersAll), isTrue);
  });

  test('restoring tolerates invalid pubspec and renamed URL entrypoint', () {
    final state = savedProject(
      query: '?entrypoint=old.dart',
      files: {
        'lib/main.dart': Uint8List.fromList([1]),
        'pubspec.yaml': Uint8List.fromList('invalid: [yaml'.codeUnits),
      },
    );
    final initial = state.initialProject(availableSdks);
    expect(initial.entrypoint, 'lib/main.dart');
    expect(initial.hasPubspec, isTrue);
    expect(initial.request.entrypoint, 'old.dart');
  });
}
