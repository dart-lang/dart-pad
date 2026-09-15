// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;

import 'project_loader.dart';

/// Downloads a GitHub gist as an in-memory [Project] with source-path mapping.
final class GistLoader {
  const GistLoader({required this.gistId});

  /// The GitHub gist identifier.
  final String gistId;

  /// Downloads gist files, moving only root-level Dart files into `lib/`.
  ///
  /// Other files retain their paths. [Project.pathMapping] records the original
  /// paths so query options can still address the moved Dart files by name.
  Future<Project> loadGist() async {
    if (gistId.isEmpty) {
      throw ArgumentError.value(gistId, 'gistId', 'must not be empty');
    }

    final response = await http.get(
      Uri.https('api.github.com', '/gists/$gistId'),
      headers: const {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to load gist $gistId (${response.statusCode})');
    }

    final Object? json = jsonDecode(response.body);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Unexpected gist response.');
    }
    if (json['truncated'] == true) {
      throw const FormatException('The gist file list is truncated.');
    }

    final filesJson = json['files'];
    if (filesJson is! Map<String, Object?>) {
      throw const FormatException('Unexpected gist files response.');
    }

    final fetchedFiles = await Future.wait(
      filesJson.values.map(_loadFile).toList(),
    );
    // Validate original names before relocation, then reject destination collisions.
    final original = Project(fetchedFiles);
    final mapping = <String, String>{
      for (final path in original.paths)
        path: parentWorkspacePath(path).isEmpty && path.endsWith('.dart') ? 'lib/$path' : path,
    };
    return Project([
      for (final file in original.files) ProjectFile(path: mapping[file.path]!, bytes: file.bytes),
    ], pathMapping: mapping);
  }

  Future<ProjectFile> _loadFile(Object? value) async {
    if (value is! Map<String, Object?>) {
      throw const FormatException('Unexpected gist file response.');
    }

    final filename = value['filename'];
    if (filename is! String || filename.isEmpty) {
      throw const FormatException('A gist file has no filename.');
    }

    if (value['truncated'] == true) {
      final rawUrl = value['raw_url'];
      if (rawUrl is! String) {
        throw const FormatException('A truncated gist file has no raw URL.');
      }
      final rawUri = Uri.tryParse(rawUrl);
      if (rawUri == null || !rawUri.isAbsolute) {
        throw const FormatException('A truncated gist file has an invalid raw URL.');
      }
      final response = await http.get(rawUri);
      if (response.statusCode != 200) {
        throw Exception('Failed to load truncated gist file $filename.');
      }
      return ProjectFile(path: filename, bytes: response.bodyBytes);
    }

    final content = value['content'];
    if (content is! String) {
      throw FormatException('A gist file has no content: $filename');
    }
    return ProjectFile(
      path: filename,
      bytes: Uint8List.fromList(utf8.encode(content)),
    );
  }
}
