// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'project_source.dart';

/// A bundled example selected by its sample ID.
final class SampleProjectSource extends ProjectSource {
  /// Describes [sampleId], or the default sample (`counter`) when null.
  const SampleProjectSource([this.sampleId]);

  /// Explicit sample ID, or null to use the bundled default. Empty IDs are invalid.
  final String? sampleId;

  @override
  Future<Project> loadProject() async {
    final id = sampleId;
    final example = id == null ? Examples.defaultExample : Examples.getById(id);
    if (example == null) {
      throw ArgumentError.value(sampleId, 'sampleId', 'Unknown example ID');
    }
    return _loadArchive(example.archivePath);
  }
}
