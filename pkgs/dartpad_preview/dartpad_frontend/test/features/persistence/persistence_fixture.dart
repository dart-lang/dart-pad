// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/models/tab_descriptor.dart';
import 'package:dartpad_frontend/features/persistence/persisted_project_state.dart';
import 'package:dartpad_frontend/features/persistence/project_store.dart';
import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/sdks.g.dart';

PersistedProjectState savedProject({
  String query = '?sample=counter',
  String text = 'void main() { print("previous work"); }',
  Map<String, Uint8List>? files,
}) => PersistedProjectState(
  query: Uri.parse(query).queryParametersAll,
  sdk: availableSdks.firstWhere((sdk) => !sdk.isFlutter),
  root: '',
  entrypoint: 'lib/main.dart',
  mode: RunMode.console,
  tabs: const [TabDescriptor(path: 'lib/main.dart', origin: EditorTabOrigin.workspace)],
  activeFile: 'lib/main.dart',
  files: files ?? {'lib/main.dart': Uint8List.fromList(utf8.encode(text))},
  folders: const ['lib', 'empty'],
);

final class MemoryProjectStore implements ProjectStore {
  MemoryProjectStore([PersistedProjectState? state]) {
    if (state != null) {
      entries['saved'] = StoredProject(id: 'saved', ownerId: 'previous-tab', updatedAt: ++_clock, state: state);
    }
  }

  final entries = <String, StoredProject>{};
  final _changes = StreamController<String>.broadcast();
  int _clock = 0;
  int _sequence = 0;
  int writes = 0;
  int reads = 0;
  int closes = 0;
  final closed = Completer<void>();
  Object? readError;
  Object? closeError;
  Object? writeError;
  Future<void>? writeBarrier;

  PersistedProjectState? get state => _sorted.firstOrNull?.state;
  List<StoredProject> get _sorted => entries.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Stream<String> get changes => _changes.stream;

  void _checkRead() {
    reads++;
    if (readError != null) {
      Error.throwWithStackTrace(readError!, StackTrace.current);
    }
  }

  @override
  Future<List<StoredProject>> list() async {
    _checkRead();
    return _sorted;
  }

  @override
  Future<StoredProject?> read(String id) async {
    _checkRead();
    return entries[id];
  }

  @override
  Future<StoredProject> create(PersistedProjectState state, {required String ownerId}) async {
    await _beforeWrite();
    final result = _put('new-${++_sequence}', ownerId, state);
    for (final entry in _sorted.skip(10)) {
      entries.remove(entry.id);
      _changes.add(entry.id);
    }
    return result;
  }

  @override
  Future<StoredProject> claim(String id, {required String ownerId}) async {
    await _beforeWrite();
    final previous = entries[id];
    if (previous == null) {
      throw const ProjectStoreConflict();
    }
    final result = _put(id, ownerId, previous.state);
    _changes.add(id);
    return result;
  }

  @override
  Future<void> write(String id, PersistedProjectState state, {required String ownerId}) async {
    await _beforeWrite();
    if (entries[id]?.ownerId != ownerId) {
      throw const ProjectStoreConflict();
    }
    _put(id, ownerId, state);
  }

  Future<void> _beforeWrite() async {
    await writeBarrier;
    if (writeError != null) {
      Error.throwWithStackTrace(writeError!, StackTrace.current);
    }
  }

  StoredProject _put(String id, String ownerId, PersistedProjectState state) {
    writes++;
    return entries[id] = StoredProject(id: id, ownerId: ownerId, updatedAt: ++_clock, state: state);
  }

  @override
  void close() {
    closes++;
    if (!closed.isCompleted) {
      closed.complete();
    }
    unawaited(_changes.close());
    if (closeError case final error?) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }
}
