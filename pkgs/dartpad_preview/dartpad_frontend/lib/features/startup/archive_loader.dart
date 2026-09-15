// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

import 'project_loader.dart';

/// A loader that downloads a (gzipped) tar archive from a remote URL,
/// returning its prepared files for the shared project resolver.
final class ArchiveLoader {
  const ArchiveLoader({required this.archiveUrl});

  final String archiveUrl;

  static Future<ArchiveLoader> forPackage(String packageName, {String? version}) async {
    final uri = Uri(
      scheme: 'https',
      host: 'pub.dev',
      pathSegments: [
        'api',
        'packages',
        packageName,
        if (version != null) ...['versions', version],
      ],
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw FormatException(
        'Failed to load package $packageName${version == null ? '' : ' version $version'} (${response.statusCode}).',
      );
    }
    final Object? json = jsonDecode(response.body);
    final Object? metadata = version == null && json is Map<String, Object?> ? json['latest'] : json;
    if (metadata is Map<String, Object?> && metadata['archive_url'] is String) {
      return ArchiveLoader(archiveUrl: metadata['archive_url'] as String);
    }
    throw const FormatException('Unexpected package response.');
  }

  /// Downloads and prepares files without starting or writing to a workspace.
  Future<Project> loadArchive() async {
    final Uri uri = Uri.base.resolve(archiveUrl);
    if (!uri.isAbsolute) {
      throw ArgumentError('archiveUrl must resolve to an absolute URI: $archiveUrl');
    }

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load archive');
    }

    final Uint8List bytes = response.bodyBytes;
    List<int> tarBytes = bytes;
    if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      tarBytes = const GZipDecoder().decodeBytes(bytes);
    }

    final Archive archive = TarDecoder().decodeBytes(tarBytes);

    final project = Project([
      for (final ArchiveFile file in archive.files)
        if (file.isFile)
          ProjectFile(
            path: _relativePath(file.name),
            bytes: file.content,
          ),
    ]);

    _disableWorkspaceResolution(project);
    return project;
  }

  /// Isolates packages in the loaded archive from a workspace that is not part
  /// of the archive.
  ///
  /// This mirrors `dart pub unpack`: the original pubspec remains unchanged,
  /// while `resolution: workspace` is disabled through a package-local
  /// `pubspec_overrides.yaml` file.
  void _disableWorkspaceResolution(Project project) {
    for (final path in project.paths.toList()) {
      if (basenameWorkspacePath(path) == 'pubspec.yaml') {
        _disableWorkspaceResolutionForPackage(
          project,
          parentWorkspacePath(path),
        );
      }
    }
  }

  void _disableWorkspaceResolutionForPackage(
    Project project,
    String projectDir,
  ) {
    final pubspecPath = joinWorkspacePath(projectDir, 'pubspec.yaml');
    final pubspecBytes = project.readFile(pubspecPath);
    if (pubspecBytes == null) {
      return;
    }

    final String pubspecContents;
    try {
      pubspecContents = utf8.decode(pubspecBytes);
    } on FormatException {
      return;
    }

    if (!_usesWorkspaceResolution(pubspecContents)) {
      return;
    }

    final overridesPath = joinWorkspacePath(projectDir, 'pubspec_overrides.yaml');
    project.writeFile(
      overridesPath,
      Uint8List.fromList(utf8.encode(jsonEncode({'resolution': null}))),
    );
  }

  bool _usesWorkspaceResolution(String pubspecContents) {
    try {
      final Object? rootValue = loadYaml(pubspecContents);
      return rootValue is Map<Object?, Object?> && rootValue['resolution'] == 'workspace';
    } on YamlException {
      return false;
    }
  }

  String _relativePath(String path) {
    if (path.startsWith('./')) {
      return path.substring(2);
    }
    return path;
  }
}
