// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;
import 'package:tar/tar.dart';
import 'package:yaml/yaml.dart';

import 'examples.g.dart';
import 'gzip/gzip.dart';
import 'project_loader.dart';

part 'archive_project_source.dart';
part 'gist_project_source.dart';
part 'package_project_source.dart';
part 'sample_project_source.dart';

/// The source from which a project's files are loaded.
///
/// Describes and loads a bundled sample, remote archive, pub.dev package, or
/// GitHub gist.
sealed class ProjectSource {
  /// Creates the base source for a concrete project source.
  const ProjectSource();

  /// Describes a bundled sample; null selects the default sample (`counter`).
  const factory ProjectSource.example([String? sampleId]) = SampleProjectSource;

  /// Loads and prepares the files supplied by this source.
  Future<Project> loadProject();
}
