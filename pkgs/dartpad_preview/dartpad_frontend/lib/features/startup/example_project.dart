// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'archive_loader.dart';
import 'examples.g.dart';
import 'project_loader.dart';

/// Loads the bundled sample, or the default sample when [sampleId] is null.
Future<Project> loadSampleProject({String? sampleId}) async {
  final example = sampleId == null ? Examples.defaultExample : Examples.getById(sampleId);
  if (example == null) {
    throw ArgumentError.value(sampleId, 'sampleId', 'Unknown example ID');
  }
  return ArchiveLoader(archiveUrl: example.archivePath).loadArchive();
}
