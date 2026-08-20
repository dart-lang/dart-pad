// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

import 'archive_loader.dart';
import 'examples.g.dart';
import 'project_loader.dart';

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

  return _loadExample(root, example, onFailure: onFailure);
}

Future<LoadedProject> _loadExample(
  WorkspaceFolder root,
  Example example, {
  ExampleLoadFailureHandler? onFailure,
}) async {
  final loader = ArchiveLoader(
    archiveUrl: example.archivePath,
    filePath: example.entryPath,
  );

  return loader.loadArchive(root);
}

/// The default entry path for example projects.
const String exampleProjectEntryPath = 'lib/main.dart';

/// Opens the default example files and leaves the Dart source active.
Future<void> openExampleProject(Future<void> Function(String path) openFile) {
  return openFile(exampleProjectEntryPath);
}
