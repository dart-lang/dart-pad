// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;

import '../shared/sdk_info.dart';
import 'project_loader.dart';

/// Loads all files of a GitHub gist into a virtual workspace.
class GistLoader {
  const GistLoader({required this.gistId});

  /// The GitHub gist identifier.
  final String gistId;

  /// Downloads the gist, writes its files into [root], and returns the
  /// detected project directory and optional entry file.
  Future<LoadedProject> loadGist(
    WorkspaceFolder root,
  ) async {
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

    final json = jsonDecode(response.body);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Unexpected gist response.');
    }
    if (json['truncated'] == true) {
      throw const FormatException('The gist file list is truncated.');
    }

    final filesJson = json['files'];
    if (filesJson is! Map<String, dynamic>) {
      throw const FormatException('Unexpected gist files response.');
    }

    final fetchedFiles = await Future.wait(
      filesJson.values.map(_loadFile).toList(),
    );
    final projectFiles = _moveRootDartFilesIntoLib(fetchedFiles);
    if (!projectFiles.any((file) => file.path == 'pubspec.yaml')) {
      projectFiles.add(_createDefaultPubspecFile(projectFiles));
    }
    final project = Project(projectFiles);
    final entryPath = _findEntryPath(project);
    final packageRoot = entryPath == null ? null : ProjectLoader.findProjectDirectory(project, entryPath);

    await ProjectLoader.writeFiles(root, project);
    return LoadedProject(
      projectDir: packageRoot ?? '',
      entryPath: entryPath,
      packageRoot: packageRoot,
      pathToMain: entryPath,
    );
  }

  Future<ProjectFile> _loadFile(dynamic value) async {
    if (value is! Map<String, dynamic>) {
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

  /// Converts the flat source layout supplied by GitHub Gists to a Dart
  /// package layout. Non-Dart files, including pubspec.yaml and assets, stay
  /// at the package root.
  List<ProjectFile> _moveRootDartFilesIntoLib(List<ProjectFile> files) {
    return [
      for (final file in files)
        if (workspaceContext.dirname(file.path).isEmpty && file.path.endsWith('.dart'))
          ProjectFile(path: 'lib/${file.path}', bytes: file.bytes)
        else
          file,
    ];
  }

  /// Matches imports and exports that reference packages.
  static final importsRegex = RegExp(r'''^(?:import|export)\s['"]package:([^/]+)/[^'"]+['"]''', multiLine: true);

  /// Creates a default pubspec.yaml for a project with the files.
  ///
  /// Includes packages that are imported by the project as dependencies.
  ProjectFile _createDefaultPubspecFile(List<ProjectFile> files) {
    final dependencies = <String, String>{};

    for (final file in files) {
      if (!file.path.endsWith('.dart')) continue;
      final content = utf8.decode(file.bytes, allowMalformed: true);
      for (final match in importsRegex.allMatches(content)) {
        final packageName = match.group(1)!;
        if (!dependencies.containsKey(packageName)) {
          dependencies[packageName] = packageName == 'flutter' ? '\n    sdk: flutter' : 'any';
        }
      }
    }

    final sortedDependencies = dependencies.entries.toList();
    sortedDependencies.sort((a, b) => a.key.compareTo(b.key));

    return ProjectFile(
      path: 'pubspec.yaml',
      bytes: Uint8List.fromList(
        utf8.encode('''
name: app

environment:
  sdk: ^3.13.0

dependencies:
  ${sortedDependencies.map((e) => '${e.key}: ${e.value}').join('\n  ')}
'''),
      ),
    );
  }

  String? _findEntryPath(Project project) {
    final paths = project.paths.toSet();
    for (final path in const ['lib/main.dart', 'main.dart']) {
      if (paths.contains(path)) {
        return path;
      }
    }

    final dartFiles = paths.where((path) => path.endsWith('.dart')).toList();
    if (dartFiles.length == 1) {
      return dartFiles.single;
    }
    return paths.contains('README.md') ? 'README.md' : null;
  }
}
