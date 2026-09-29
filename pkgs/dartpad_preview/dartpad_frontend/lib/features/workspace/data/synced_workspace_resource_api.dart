// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';

/// An implementation of [WorkspaceResourceApi] that maintains a local in-memory file system
/// as the primary source of truth for reads and outgoing change events, while asynchronously
/// initializing and continuously synchronizing with a remote file system.
class SyncedWorkspaceResourceApi implements WorkspaceResourceApi {
  SyncedWorkspaceResourceApi({
    required this.localApi,
    Future<WorkspaceResourceApi>? remoteApi,
    this.onLocalToRemoteSyncError,
    this.onRemoteToLocalSyncError,
  }) {
    if (remoteApi != null) {
      connect(remoteApi);
    }
  }

  final WorkspaceResourceApi localApi;
  final void Function(Object error, StackTrace stackTrace)? onLocalToRemoteSyncError;
  final void Function(Object error, StackTrace stackTrace)? onRemoteToLocalSyncError;
  WorkspaceResourceApi? remoteApi;
  StreamSubscription<WorkspaceChangeEvent>? _remoteSubscription;
  Future<void> _apiReady = Future.value();
  _RemoteInitialization? _initialization;
  bool _isDisposed = false;

  Future<void> _remoteQueue = Future<void>.value();

  /// Completes when the remote API is initialized and initial file synchronization is complete.
  Future<void> get apiReady => _apiReady;

  /// Attaches a fresh worker after startup or suspension. Local reads and writes
  /// remain available while it boots and are copied during initial sync.
  void connect(Future<WorkspaceResourceApi> remoteApiFuture) {
    if (_isDisposed || _initialization != null) {
      throw StateError('Disconnect the previous workspace before connecting.');
    }
    final initialization = _initialization = _RemoteInitialization();
    final ready = Completer<void>();
    _apiReady = ready.future;
    _remoteQueue = _remoteQueue.then((_) async {
      try {
        final api = await remoteApiFuture;
        if (_isDisposed || !identical(initialization, _initialization)) {
          if (initialization.disposeOnArrival) {
            await api.dispose();
          }
          return;
        }
        remoteApi = api;

        final resources = await localApi.listDirectory(uri: '', recursive: true);
        for (final r in resources) {
          if (_isDisposed || !identical(initialization, _initialization)) {
            return;
          }
          if (r.type == 'folder') {
            await api.createFolder(r.path);
          } else {
            final bytes = await localApi.readFileAsBytes(r.path);
            await api.writeFileFromBytes(r.path, bytes);
          }
        }

        if (!_isDisposed && identical(initialization, _initialization)) {
          _startWatchingRemote(api);
        }
      } catch (error, stackTrace) {
        if (!ready.isCompleted) {
          ready.completeError(error, stackTrace);
        }
      } finally {
        if (!ready.isCompleted) {
          ready.complete();
        }
      }
    });
  }

  /// Stops synchronization while retaining the local filesystem.
  Future<void> disconnect({bool disposeRemote = true}) async {
    _initialization?.disposeOnArrival = disposeRemote;
    _initialization = null;
    final api = remoteApi;
    final subscription = _remoteSubscription;
    remoteApi = null;
    _remoteSubscription = null;
    _remoteQueue = Future.value();
    _apiReady = Future.value();
    await subscription?.cancel();
    if (disposeRemote) {
      await api?.dispose();
    }
  }

  /// Waits for all currently queued remote filesystem operations and initial synchronization to complete.
  Future<void> flush() => _remoteQueue;

  void _queueRemoteAction(FutureOr<void> Function(WorkspaceResourceApi ws) action) {
    final api = remoteApi;
    if (api == null || _isDisposed) {
      return;
    }
    _remoteQueue = _remoteQueue.then((_) async {
      if (_isDisposed || !identical(remoteApi, api)) {
        return;
      }
      try {
        await action(api);
      } catch (error, stackTrace) {
        if (!_isDisposed && identical(remoteApi, api)) {
          onLocalToRemoteSyncError?.call(error, stackTrace);
        }
      }
    });
  }

  void _startWatchingRemote(WorkspaceResourceApi ws) {
    _remoteSubscription = ws.changeEvents.listen(
      (event) async {
        if (_isDisposed || !identical(remoteApi, ws)) {
          return;
        }
        try {
          await _applyRemoteChange(ws, event);
        } catch (error, stackTrace) {
          if (!_isDisposed && identical(remoteApi, ws)) {
            onRemoteToLocalSyncError?.call(error, stackTrace);
          }
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!_isDisposed && identical(remoteApi, ws)) {
          onRemoteToLocalSyncError?.call(error, stackTrace);
        }
      },
    );
  }

  Future<void> _applyRemoteChange(WorkspaceResourceApi ws, WorkspaceChangeEvent event) async {
    bool current() => !_isDisposed && identical(remoteApi, ws);
    switch (event.type) {
      case WorkspaceChangeEventType.add:
      case WorkspaceChangeEventType.modify:
        if (await ws.folderExist(event.path)) {
          if (current() && !await localApi.folderExist(event.path) && current()) {
            await localApi.createFolder(event.path);
          }
        } else if (await ws.fileExist(event.path)) {
          final workerBytes = await ws.readFileAsBytes(event.path);
          if (!current()) {
            return;
          }
          if (await localApi.fileExist(event.path)) {
            final memBytes = await localApi.readFileAsBytes(event.path);
            if (_areBytesEqual(memBytes, workerBytes)) {
              return;
            }
          }
          if (current()) {
            await localApi.writeFileFromBytes(event.path, workerBytes);
          }
        }
      case WorkspaceChangeEventType.remove:
        if (await localApi.fileExist(event.path) || await localApi.folderExist(event.path)) {
          if (current()) {
            await localApi.deleteFileSystemEntity(event.path);
          }
        }
      case WorkspaceChangeEventType.move:
        final oldPath = event.oldPath;
        if (oldPath != null && current()) {
          localApi.addMoveIntention(oldPath, event.path);
        }
        if (await ws.folderExist(event.path)) {
          if (current() && !await localApi.folderExist(event.path) && current()) {
            await localApi.createFolder(event.path);
          }
          if (oldPath != null && await localApi.folderExist(oldPath) && current()) {
            await localApi.deleteFileSystemEntity(oldPath);
          }
        } else if (await ws.fileExist(event.path)) {
          final workerBytes = await ws.readFileAsBytes(event.path);
          if (!current()) {
            return;
          }
          await localApi.writeFileFromBytes(event.path, workerBytes);
          if (oldPath != null && await localApi.fileExist(oldPath) && current()) {
            await localApi.deleteFileSystemEntity(oldPath);
          }
        }
    }
  }

  @override
  Future<bool> fileExist(String uri) => localApi.fileExist(uri);

  @override
  Future<bool> folderExist(String uri) => localApi.folderExist(uri);

  @override
  Future<String> readFileAsText(String uri) => localApi.readFileAsText(uri);

  @override
  Future<Uint8List> readFileAsBytes(String uri) => localApi.readFileAsBytes(uri);

  @override
  Future<void> writeFileFromText(String uri, String content) async {
    await localApi.writeFileFromText(uri, content);
    _queueRemoteAction((ws) => ws.writeFileFromText(uri, content));
  }

  @override
  Future<void> writeFileFromBytes(String uri, Uint8List bytes) async {
    await localApi.writeFileFromBytes(uri, bytes);
    _queueRemoteAction((ws) => ws.writeFileFromBytes(uri, bytes));
  }

  @override
  Future<void> createFolder(String uri) async {
    await localApi.createFolder(uri);
    _queueRemoteAction((ws) => ws.createFolder(uri));
  }

  @override
  Future<void> deleteFileSystemEntity(String uri) async {
    await localApi.deleteFileSystemEntity(uri);
    _queueRemoteAction((ws) => ws.deleteFileSystemEntity(uri));
  }

  @override
  Future<List<({String path, String type})>> listDirectory({required String uri, bool recursive = false}) =>
      localApi.listDirectory(uri: uri, recursive: recursive);

  @override
  void addMoveIntention(String oldPath, String newPath) {
    localApi.addMoveIntention(oldPath, newPath);
    _queueRemoteAction((ws) => ws.addMoveIntention(oldPath, newPath));
  }

  @override
  Stream<WorkspaceChangeEvent> get changeEvents => localApi.changeEvents;

  @override
  Future<void> get changeEventsReady => localApi.changeEventsReady;

  @override
  Future<void> dispose() async {
    _isDisposed = true;
    await disconnect();
    await localApi.dispose();
  }
}

final class _RemoteInitialization {
  bool disposeOnArrival = true;
}

bool _areBytesEqual(Uint8List a, Uint8List b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.lengthInBytes != b.lengthInBytes) {
    return false;
  }
  for (var i = 0; i < a.lengthInBytes; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
