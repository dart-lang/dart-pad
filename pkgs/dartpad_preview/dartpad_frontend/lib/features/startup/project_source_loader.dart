// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'archive_loader.dart';
import 'example_project.dart';
import 'gist_loader.dart';
import 'project_loader.dart';
import 'project_request.dart';

/// Loads project contents using the loader for the requested source type.
Future<Project> loadProjectSource(ProjectSource source) async => switch (source) {
  SampleProjectSource(:final sampleId) => loadSampleProject(sampleId: sampleId),
  ArchiveProjectSource(:final url) => ArchiveLoader(archiveUrl: url).loadArchive(),
  PackageProjectSource(:final package, :final version) => (await ArchiveLoader.forPackage(
    package,
    version: version,
  )).loadArchive(),
  GistProjectSource(:final id) => GistLoader(gistId: id).loadGist(),
};
