// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

import 'archive_loader.dart';
import 'project_loader.dart';
import 'samples.g.dart';

/// Loads a sample project from its packaged archive into [root].
///
/// Throws an [ArgumentError] when [sampleId] does not match any known sample.
/// Archive download errors propagate to the caller.
Future<LoadedProject> loadSampleProject(
  WorkspaceFolder root, {
  String? sampleId,
}) async {
  final requestedSample = Samples.getById(sampleId);
  if (sampleId != null && requestedSample == null) {
    throw ArgumentError.value(sampleId, 'sampleId', 'Unknown sample ID');
  }

  final sample = requestedSample ?? Samples.defaultSample;
  final loader = ArchiveLoader(
    archiveUrl: sample.archivePath,
    filePath: sample.entryPath,
  );

  return loader.loadArchive(root);
}

/// The default entry path for sample projects.
const String sampleProjectEntryPath = 'lib/main.dart';

/// Opens the default sample files and leaves the Dart source active.
Future<void> openSampleProject(Future<void> Function(String path) openFile) {
  return openFile(sampleProjectEntryPath);
}
