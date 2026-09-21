// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'persisted_project_state.dart';

/// One project in the history, updated in place by any browser tab.
final class StoredProject {
  const StoredProject({required this.id, required this.updatedAt, required this.state});

  /// Opaque local identifier for this history entry, stable across updates.
  final String id;
  final int updatedAt;
  final PersistedProjectState state;
}

abstract interface class ProjectStore {
  /// Most recently saved first; at most ten projects.
  Future<List<StoredProject>> list();
  Future<StoredProject?> read(String id);
  Future<StoredProject> create(PersistedProjectState state);

  /// Atomically saves files and metadata. The last write wins, including for
  /// entries previously evicted from the history.
  Future<void> write(String id, PersistedProjectState state);
  void close();
}
