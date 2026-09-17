// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'persisted_project_state.dart';

/// One project in the history, updated in place by its owning browser tab.
final class StoredProject {
  const StoredProject({required this.id, required this.ownerId, required this.updatedAt, required this.state});

  final String id;
  final String ownerId;
  final int updatedAt;
  final PersistedProjectState state;
}

abstract interface class ProjectStore {
  /// IDs of projects changed or evicted by another store connection.
  Stream<String> get changes;

  /// Most recently saved first; at most ten projects.
  Future<List<StoredProject>> list();
  Future<StoredProject?> read(String id);
  Future<StoredProject> create(PersistedProjectState state, {required String ownerId});

  /// Atomically reads the current snapshot and transfers ownership.
  Future<StoredProject> claim(String id, {required String ownerId});

  /// Atomically checks ownership before updating files and metadata.
  Future<void> write(String id, PersistedProjectState state, {required String ownerId});
  void close();
}

/// The project was taken over by another tab or evicted from the history.
final class ProjectStoreConflict implements Exception {
  const ProjectStoreConflict();
}
