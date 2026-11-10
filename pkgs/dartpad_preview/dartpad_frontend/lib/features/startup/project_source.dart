// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;
import 'package:tar/tar.dart';
import 'package:yaml/yaml.dart';

import '../shared/flutter_api_channel.dart';
import '../shared/project_exceptions.dart';
import 'examples.g.dart';
import 'gzip/gzip.dart';
import 'project_loader.dart';
import 'query_parameters.dart';
import 'strip_unavailable_dependencies.dart';

part 'archive_project_source.dart';
part 'flutter_api_docs_project_source.dart';
part 'gist_project_source.dart';
part 'package_project_source.dart';
part 'sample_project_source.dart';

/// The source from which a project's files are loaded.
///
/// Describes and loads a bundled sample, remote archive, pub.dev package,
/// GitHub gist, or generated Flutter API documentation sample.
sealed class ProjectSource {
  /// Creates the base source for a concrete project source.
  const ProjectSource();

  /// Describes a bundled sample; null selects the default sample (`counter`).
  const factory ProjectSource.example([String? sampleId]) = SampleProjectSource;

  /// Describes a generated Flutter API documentation sample.
  const factory ProjectSource.flutterApiDocs(String sampleId, {FlutterApiChannel? channel}) =
      FlutterApiDocsProjectSource;

  /// Loads and prepares the files supplied by this source.
  Future<Project> loadProject();
}

/// A failed browser request may have no HTTP response (for example, offline or CORS).
Future<http.Response> _getSourceResponse(
  Uri uri, {
  required String failureMessage,
  Map<String, String>? headers,
}) async {
  try {
    return await http.get(uri, headers: headers);
  } on http.ClientException {
    throw ProjectSourceException(
      '$failureMessage. Check your connection and whether the source allows browser access.',
    );
  }
}

/// Decodes a remote JSON response, reporting malformed bodies as [ProjectSourceException].
Object? _decodeSourceJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    throw const ProjectSourceException("Could not parse project's source response.");
  }
}
