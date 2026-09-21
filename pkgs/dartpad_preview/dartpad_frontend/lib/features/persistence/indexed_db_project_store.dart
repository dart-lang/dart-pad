// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'persisted_project_state.dart';
import 'project_store.dart';

/// Keeps ten projects. Metadata and binary files are committed together;
/// the last write wins and history eviction runs in the same transaction.
final class IndexedDbProjectStore implements ProjectStore {
  IndexedDbProjectStore({this.databaseName = 'dartpad-preview-project'});

  final String databaseName;
  Future<web.IDBDatabase>? _database;
  bool _closed = false;

  Future<web.IDBDatabase> _open() async {
    if (_closed) {
      throw StateError('Local project storage is closed.');
    }
    final opening = _database ??= _openDatabase();
    try {
      return await opening;
    } catch (_) {
      if (identical(_database, opening)) {
        _database = null;
      }
      rethrow;
    }
  }

  Future<web.IDBDatabase> _openDatabase() async {
    final result = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(databaseName);
    request.onupgradeneeded = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      db.createObjectStore('projects');
    }).toJS;
    request.onsuccess = ((web.Event event) {
      final db = request.result as web.IDBDatabase;
      db.onversionchange = ((web.Event event) => db.close()).toJS;
      if (_closed || result.isCompleted) {
        db.close();
      } else {
        result.complete(db);
      }
    }).toJS;
    request.onerror = ((web.Event event) {
      if (!result.isCompleted) {
        result.completeError(StateError('Could not open local project storage.'));
      }
    }).toJS;
    final timer = Timer(const Duration(seconds: 3), () {
      if (!result.isCompleted) {
        result.completeError(TimeoutException('Local project storage is unavailable.'));
      }
    });
    try {
      return await result.future;
    } finally {
      timer.cancel();
    }
  }

  @override
  Future<List<StoredProject>> list() async {
    final db = await _open();
    final transaction = db.transaction('projects'.toJS, 'readonly');
    final results = await Future.wait<Object?>([
      _request(transaction.objectStore('projects').getAll()),
      _complete(transaction),
    ]);
    return (results.first as JSArray<JSObject>).toDart.map(_decode).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  @override
  Future<StoredProject?> read(String id) async {
    final db = await _open();
    final transaction = db.transaction('projects'.toJS, 'readonly');
    final results = await Future.wait<Object?>([
      _request(transaction.objectStore('projects').get(id.toJS)),
      _complete(transaction),
    ]);
    return results.first == null ? null : _decode(results.first as JSObject);
  }

  @override
  Future<StoredProject> create(PersistedProjectState state) => _commit(web.window.crypto.randomUUID(), state);

  @override
  Future<void> write(String id, PersistedProjectState state) async {
    await _commit(id, state);
  }

  Future<StoredProject> _commit(String id, PersistedProjectState state) async {
    final db = await _open();
    final transaction = db.transaction('projects'.toJS, 'readwrite');
    final done = _complete(transaction);
    final projects = transaction.objectStore('projects');
    final request = projects.getAll();
    StoredProject? committed;
    Object? failure;
    request.onsuccess = ((web.Event event) {
      try {
        final records = (request.result as JSArray<JSObject>).toDart;
        var updatedAt = DateTime.now().millisecondsSinceEpoch;
        for (final record in records) {
          final timestamp = record.getProperty<JSNumber>('updatedAt'.toJS).toDartInt;
          if (timestamp >= updatedAt) {
            updatedAt = timestamp + 1;
          }
        }
        committed = StoredProject(id: id, updatedAt: updatedAt, state: state);
        projects.put(_encode(committed!), id.toJS);
        final older = records.where((record) => _string(record, 'id') != id).toList()
          ..sort(
            (a, b) => b
                .getProperty<JSNumber>('updatedAt'.toJS)
                .toDartInt
                .compareTo(a.getProperty<JSNumber>('updatedAt'.toJS).toDartInt),
          );
        for (final record in older.skip(9)) {
          final removedId = _string(record, 'id');
          projects.delete(removedId.toJS);
        }
      } catch (error) {
        failure = error;
        transaction.abort();
      }
    }).toJS;
    try {
      await done;
    } catch (_) {
      if (failure != null) {
        Error.throwWithStackTrace(failure!, StackTrace.current);
      }
      rethrow;
    }
    return committed!;
  }

  @override
  void close() {
    _closed = true;
    unawaited(_database?.then((db) => db.close(), onError: (Object _) {}));
  }
}

JSObject _encode(StoredProject project) => JSObject()
  ..setProperty('id'.toJS, project.id.toJS)
  ..setProperty('updatedAt'.toJS, project.updatedAt.toJS)
  ..setProperty('metadata'.toJS, jsonEncode(project.state.metadata()).toJS)
  ..setProperty(
    'files'.toJS,
    [
      for (final entry in project.state.files.entries)
        JSObject()
          ..setProperty('path'.toJS, entry.key.toJS)
          ..setProperty('bytes'.toJS, entry.value.toJS),
    ].toJS,
  );

String _string(JSObject value, String key) => value.getProperty<JSString>(key.toJS).toDart;

StoredProject _decode(JSObject value) => StoredProject(
  id: _string(value, 'id'),
  updatedAt: value.getProperty<JSNumber>('updatedAt'.toJS).toDartInt,
  state: PersistedProjectState.decode(
    jsonDecode(_string(value, 'metadata')) as Map<String, Object?>,
    {
      for (final file in value.getProperty<JSArray<JSObject>>('files'.toJS).toDart)
        _string(file, 'path'): Uint8List.fromList(file.getProperty<JSUint8Array>('bytes'.toJS).toDart),
    },
  ),
);

Future<JSAny?> _request(web.IDBRequest request) {
  final completer = Completer<JSAny?>();
  request.onsuccess = ((web.Event event) => completer.complete(request.result)).toJS;
  request.onerror = ((web.Event event) => completer.completeError(
    StateError('Could not read local project storage.'),
  )).toJS;
  return completer.future;
}

Future<void> _complete(web.IDBTransaction transaction) {
  final completer = Completer<void>();
  transaction.oncomplete = ((web.Event event) => completer.complete()).toJS;
  transaction.onabort = ((web.Event event) => completer.completeError(
    StateError('Could not save local project storage.'),
  )).toJS;
  return completer.future;
}
