// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/workspace/data/synced_workspace_resource_api.dart';
import 'package:test/test.dart';

void main() {
  group('SyncedWorkspaceResourceApi', () {
    late MemoryWorkspaceResourceApi localApi;
    late Completer<WorkspaceResourceApi> remoteApiCompleter;
    late MemoryWorkspaceResourceApi remoteApi;
    late SyncedWorkspaceResourceApi syncedApi;

    setUp(() async {
      localApi = MemoryWorkspaceResourceApi();
      await localApi.createFolder('lib');
      await localApi.writeFileFromText('lib/main.dart', 'local main');

      remoteApiCompleter = Completer<WorkspaceResourceApi>();
      remoteApi = MemoryWorkspaceResourceApi();

      syncedApi = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: remoteApiCompleter.future,
      );
    });

    test('reads directly from localApi before and after remote is loaded', () async {
      expect(await syncedApi.fileExist('lib/main.dart'), isTrue);
      expect(await syncedApi.folderExist('lib'), isTrue);
      expect(await syncedApi.readFileAsText('lib/main.dart'), 'local main');
      expect(await syncedApi.readFileAsBytes('lib/main.dart'), Uint8List.fromList('local main'.codeUnits));

      final list = await syncedApi.listDirectory(uri: 'lib');
      expect(list.map((e) => e.path), contains('main.dart'));

      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      expect(await syncedApi.readFileAsText('lib/main.dart'), 'local main');
    });

    test('syncs full filesystem tree to remote when loaded', () async {
      await syncedApi.createFolder('lib/src');
      await syncedApi.writeFileFromText('lib/src/util.dart', 'util code');
      await syncedApi.writeFileFromBytes('asset.bin', Uint8List.fromList([1, 2, 3]));

      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      expect(await remoteApi.fileExist('lib/main.dart'), isTrue);
      expect(await remoteApi.readFileAsText('lib/main.dart'), 'local main');
      expect(await remoteApi.folderExist('lib/src'), isTrue);
      expect(await remoteApi.fileExist('lib/src/util.dart'), isTrue);
      expect(await remoteApi.readFileAsText('lib/src/util.dart'), 'util code');
      expect(await remoteApi.fileExist('asset.bin'), isTrue);
      expect(await remoteApi.readFileAsBytes('asset.bin'), Uint8List.fromList([1, 2, 3]));
    });

    test('queues and applies writes arriving while initial sync is in progress', () async {
      remoteApiCompleter.complete(remoteApi);

      // Perform write immediately after remote resolves, in flight before/during sync queue
      await syncedApi.writeFileFromText('lib/during_sync.dart', 'during sync content');
      await syncedApi.writeFileFromBytes('binary_during.bin', Uint8List.fromList([4, 5, 6]));
      await syncedApi.createFolder('folder_during');

      await syncedApi.apiReady;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await remoteApi.fileExist('lib/during_sync.dart'), isTrue);
      expect(await remoteApi.readFileAsText('lib/during_sync.dart'), 'during sync content');
      expect(await remoteApi.fileExist('binary_during.bin'), isTrue);
      expect(await remoteApi.readFileAsBytes('binary_during.bin'), Uint8List.fromList([4, 5, 6]));
      expect(await remoteApi.folderExist('folder_during'), isTrue);
    });

    test('applies writes to local and queues them to remote after loading', () async {
      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      // Text write
      await syncedApi.writeFileFromText('lib/main.dart', 'updated main');
      expect(await syncedApi.readFileAsText('lib/main.dart'), 'updated main');
      expect(await localApi.readFileAsText('lib/main.dart'), 'updated main');

      // Byte write
      await syncedApi.writeFileFromBytes('data.bin', Uint8List.fromList([10, 20]));
      expect(await syncedApi.readFileAsBytes('data.bin'), Uint8List.fromList([10, 20]));

      // Folder creation
      await syncedApi.createFolder('new_dir');
      expect(await syncedApi.folderExist('new_dir'), isTrue);

      // Deletion
      await syncedApi.deleteFileSystemEntity('lib/main.dart');
      expect(await syncedApi.fileExist('lib/main.dart'), isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(await remoteApi.fileExist('lib/main.dart'), isFalse);
      expect(await remoteApi.fileExist('data.bin'), isTrue);
      expect(await remoteApi.readFileAsBytes('data.bin'), Uint8List.fromList([10, 20]));
      expect(await remoteApi.folderExist('new_dir'), isTrue);
    });

    test('propagates remote file additions, modifications, and deletions to local', () async {
      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      // Remote file addition
      await remoteApi.writeFileFromText('lib/remote_created.dart', 'remote content');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await syncedApi.fileExist('lib/remote_created.dart'), isTrue);
      expect(await syncedApi.readFileAsText('lib/remote_created.dart'), 'remote content');

      // Remote folder addition
      await remoteApi.createFolder('remote_folder');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await syncedApi.folderExist('remote_folder'), isTrue);

      // Remote file modification
      await remoteApi.writeFileFromText('lib/remote_created.dart', 'modified remote content');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await syncedApi.readFileAsText('lib/remote_created.dart'), 'modified remote content');

      // Remote deletion
      await remoteApi.deleteFileSystemEntity('lib/remote_created.dart');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await syncedApi.fileExist('lib/remote_created.dart'), isFalse);
    });

    test('propagates remote move events to local', () async {
      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      remoteApi.addMoveIntention('lib/main.dart', 'lib/renamed.dart');
      await remoteApi.writeFileFromText('lib/renamed.dart', 'local main');
      await remoteApi.deleteFileSystemEntity('lib/main.dart');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await syncedApi.fileExist('lib/main.dart'), isFalse);
      expect(await syncedApi.fileExist('lib/renamed.dart'), isTrue);
      expect(await syncedApi.readFileAsText('lib/renamed.dart'), 'local main');
    });

    test('forwards changeEvents from local and avoids duplicate events on write sync', () async {
      final events = <WorkspaceChangeEvent>[];
      final sub = syncedApi.changeEvents.listen(events.add);

      // 1. Local write emits change event
      await syncedApi.writeFileFromText('a.dart', 'content A');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events, hasLength(1));
      expect(events.first.path, 'a.dart');

      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      // 2. Write synced to remote should not cause duplicate event on local
      await syncedApi.writeFileFromText('a.dart', 'content A v2');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      // Expected: 1 event from the local write, 0 duplicate events from remote sync
      expect(events, hasLength(2));
      expect(events.last.path, 'a.dart');

      // 3. Independent remote write emits event
      await remoteApi.writeFileFromText('b.dart', 'remote B');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(events, hasLength(3));
      expect(events.last.path, 'b.dart');

      await sub.cancel();
    });

    test('handles move intention queued to remote', () async {
      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      syncedApi.addMoveIntention('lib/main.dart', 'lib/moved.dart');
      await syncedApi.writeFileFromText('lib/moved.dart', 'local main');
      await syncedApi.deleteFileSystemEntity('lib/main.dart');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(await remoteApi.fileExist('lib/main.dart'), isFalse);
      expect(await remoteApi.fileExist('lib/moved.dart'), isTrue);
    });

    test('handles disposal before remote API completes', () async {
      await syncedApi.dispose();

      // Completing future after disposal should not throw and should dispose the remote API
      remoteApiCompleter.complete(remoteApi);
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(syncedApi.remoteApi, isNull);
    });

    test('flush waits for all pending queued writes to finish on remote', () async {
      remoteApiCompleter.complete(remoteApi);
      await syncedApi.apiReady;

      await syncedApi.writeFileFromText('lib/f1.dart', '1');
      await syncedApi.writeFileFromText('lib/f2.dart', '2');

      // flush ensures all queued remote writes complete
      await syncedApi.flush();

      expect(await remoteApi.readFileAsText('lib/f1.dart'), '1');
      expect(await remoteApi.readFileAsText('lib/f2.dart'), '2');
    });

    test('handles remote API future completing with error gracefully', () async {
      remoteApiCompleter.completeError(Exception('Remote worker crashed'));

      await expectLater(
        syncedApi.apiReady,
        throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('Remote worker crashed'))),
      );

      // Local API remains operational
      await syncedApi.writeFileFromText('test.dart', 'still works');
      expect(await syncedApi.readFileAsText('test.dart'), 'still works');
      expect(syncedApi.remoteApi, isNull);
    });

    test('reports failures during initial synchronization', () async {
      remoteApiCompleter.complete(_FailingWriteWorkspaceResourceApi(failWrites: true));

      await expectLater(
        syncedApi.apiReady,
        throwsA(isA<StateError>().having((error) => error.message, 'message', 'Initial sync failed')),
      );
    });

    test('reports failed queued remote actions without breaking the queue', () async {
      final errors = <Object>[];
      final failingRemoteApi = _FailingWriteWorkspaceResourceApi();
      final api = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: Future.value(failingRemoteApi),
        onLocalToRemoteSyncError: (error, _) => errors.add(error),
      );
      await api.apiReady;
      failingRemoteApi.failWrites = true;

      await api.writeFileFromText('first.dart', 'first');
      await api.writeFileFromText('second.dart', 'second');
      await api.flush();

      expect(errors, hasLength(2));
      expect(await api.readFileAsText('first.dart'), 'first');
      expect(await api.readFileAsText('second.dart'), 'second');
    });

    test('reports failures while applying remote changes', () async {
      final errors = <Object>[];
      final failingRemoteApi = _FailingReadWorkspaceResourceApi();
      final api = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: Future.value(failingRemoteApi),
        onRemoteToLocalSyncError: (error, _) => errors.add(error),
      );
      await api.apiReady;
      failingRemoteApi.failReads = true;

      await failingRemoteApi.writeFileFromText('remote.dart', 'remote');
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
    });

    test('reports errors emitted by the remote change stream', () async {
      final errors = <Object>[];
      final erroringRemoteApi = _ErroringChangeEventsWorkspaceResourceApi();
      final api = SyncedWorkspaceResourceApi(
        localApi: localApi,
        remoteApi: Future.value(erroringRemoteApi),
        onRemoteToLocalSyncError: (error, _) => errors.add(error),
      );
      await api.apiReady;

      erroringRemoteApi.addChangeError(StateError('Remote watcher failed'));
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      await api.dispose();
    });
  });
}

final class _ErroringChangeEventsWorkspaceResourceApi extends MemoryWorkspaceResourceApi {
  final StreamController<WorkspaceChangeEvent> _changeEvents = StreamController.broadcast();

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => _changeEvents.stream;

  void addChangeError(Object error) => _changeEvents.addError(error);

  @override
  Future<void> dispose() => _changeEvents.close();
}

final class _FailingReadWorkspaceResourceApi extends MemoryWorkspaceResourceApi {
  bool failReads = false;

  @override
  Future<Uint8List> readFileAsBytes(String uri) {
    if (failReads) {
      return Future.error(StateError('Reading remote change failed'));
    }
    return super.readFileAsBytes(uri);
  }
}

final class _FailingWriteWorkspaceResourceApi extends MemoryWorkspaceResourceApi {
  _FailingWriteWorkspaceResourceApi({this.failWrites = false});

  bool failWrites;

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) {
    if (failWrites) {
      return Future.error(StateError('Initial sync failed'));
    }
    return super.writeFileFromBytes(uri, bytes);
  }

  @override
  Future<void> writeFileFromText(String uri, String content) {
    if (failWrites) {
      return Future.error(StateError('Saving failed'));
    }
    return super.writeFileFromText(uri, content);
  }
}
