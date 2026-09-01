// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;
import 'package:yaml_edit/yaml_edit.dart';

import 'project_loader.dart';

/// A loader that downloads a (gzipped) tar archive from a remote URL,
/// extracts all of its files into a virtual workspace folder, and opens a
/// target file.
class ArchiveLoader {
  /// Creates an archive loader.
  const ArchiveLoader({
    required this.archiveUrl,
    this.packageName,
    this.filePath,
    this.pathToMain,
  });

  static Future<ArchiveLoader> forPackage(
    String packageName, {
    String? pathToMain,
  }) async {
    final String url = 'https://pub.dev/api/packages/$packageName';
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load package $packageName');
    }

    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    if (json case {'latest': {'archive_url': final String archiveUrl}}) {
      return ArchiveLoader(
        archiveUrl: archiveUrl,
        packageName: packageName,
        pathToMain: pathToMain,
      );
    }

    throw Exception('Failed to load package $packageName: Unexpected JSON response.');
  }

  /// The absolute URL pointing to the tar or gzipped tar archive.
  final String archiveUrl;

  /// The name of the package that the archive belongs to.
  final String? packageName;

  /// The workspace-relative file path within the project to open in the editor
  /// after extraction.
  final String? filePath;

  /// The entrypoint file to be executed in the preview. Defaults to [filePath].
  final String? pathToMain;

  /// Downloads, decompresses, and extracts all files from the [archiveUrl]
  /// into the workspace [root].
  ///
  /// Scans the archive files to find the nearest parent directory containing
  /// a `pubspec.yaml` file for the active target file.
  ///
  /// The returned entrypoint is either [filePath], a well-known example file
  /// discovered in package archives, or a fallback `README.md` file.
  Future<LoadedProject> loadArchive(WorkspaceFolder root) async {
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

    final targetFilePath = filePath ?? findDefaultFile(archive);
    final files = <ProjectFile>[];
    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }

      files.add(
        ProjectFile(path: _relativePath(file.name), bytes: file.content),
      );
    }

    final entryPath = targetFilePath == null ? null : ProjectLoader.normalizePath(targetFilePath);
    final mainPath = pathToMain != null ? ProjectLoader.normalizePath(pathToMain!) : entryPath;
    final projectDir = entryPath == null ? '' : ProjectLoader.findProjectDirectory(files, entryPath) ?? '';

    _disableWorkspaceResolution(files, projectDir);
    await ProjectLoader.writeFiles(root, files);

    return LoadedProject(
      projectDir: projectDir,
      entryPath: entryPath,
      packageRoot: projectDir,
      pathToMain: mainPath,
    );
  }

  /// Isolates the active package from a workspace that is not part of the
  /// loaded archive.
  ///
  /// This mirrors `dart pub unpack`: the original pubspec remains unchanged,
  /// while `resolution: workspace` is disabled through a package-local
  /// `pubspec_overrides.yaml` file. Pub runs dependency resolution for an
  /// `example/` package by default. Therefore, workspace resolution must also
  /// be disabled for nested example packages to prevent `pub get` from failing
  /// there.
  void _disableWorkspaceResolution(List<ProjectFile> files, String projectDir) {
    var packageDir = projectDir;
    while (true) {
      _disableWorkspaceResolutionForPackage(files, packageDir);

      final exampleDir = _packageFilePath(packageDir, 'example');
      final examplePubspecPath = _packageFilePath(exampleDir, 'pubspec.yaml');
      if (_findFile(files, examplePubspecPath) == -1) {
        return;
      }
      packageDir = exampleDir;
    }
  }

  void _disableWorkspaceResolutionForPackage(
    List<ProjectFile> files,
    String projectDir,
  ) {
    final pubspecPath = _packageFilePath(projectDir, 'pubspec.yaml');
    final pubspecIndex = _findFile(files, pubspecPath);
    if (pubspecIndex == -1) {
      return;
    }

    final String pubspecContents;
    try {
      pubspecContents = utf8.decode(files[pubspecIndex].bytes);
    } on FormatException {
      return;
    }

    if (!_usesWorkspaceResolution(pubspecContents)) {
      return;
    }

    final overridesPath = _packageFilePath(projectDir, 'pubspec_overrides.yaml');
    final overridesIndex = _findFile(files, overridesPath);
    if (overridesIndex == -1) {
      files.add(
        ProjectFile(
          path: overridesPath,
          bytes: Uint8List.fromList(utf8.encode('resolution:\n')),
        ),
      );
      return;
    }

    final ProjectFile overridesFile = files[overridesIndex];
    final String overridesContents;
    try {
      overridesContents = utf8.decode(overridesFile.bytes);
    } on FormatException {
      return;
    }

    final updatedOverrides = _setResolutionToNull(overridesContents);
    if (updatedOverrides == null) {
      return;
    }

    files[overridesIndex] = ProjectFile(
      path: overridesFile.path,
      bytes: Uint8List.fromList(utf8.encode(updatedOverrides)),
    );
  }

  bool _usesWorkspaceResolution(String pubspecContents) {
    try {
      final editor = YamlEditor(pubspecContents);
      final rootValue = editor.parseAt(const []).value;
      return rootValue is Map && rootValue['resolution'] == 'workspace';
    } on FormatException {
      return false;
    }
  }

  String? _setResolutionToNull(String overridesContents) {
    try {
      final editor = YamlEditor(overridesContents);
      final rootValue = editor.parseAt(const []).value;
      if (rootValue == null) {
        editor.update(const [], {'resolution': null});
      } else if (rootValue is Map) {
        editor.update(const ['resolution'], null);
      } else {
        return null;
      }
      return editor.toString();
    } on FormatException {
      return null;
    }
  }

  int _findFile(List<ProjectFile> files, String path) {
    return files.indexWhere(
      (file) => ProjectLoader.normalizePath(file.path) == path,
    );
  }

  String _packageFilePath(String projectDir, String filename) {
    return projectDir.isEmpty ? filename : '$projectDir/$filename';
  }

  String _relativePath(String path) {
    if (path.startsWith('./')) {
      return path.substring(2);
    }
    if (path.startsWith('/')) {
      return path.substring(1);
    }
    return path;
  }

  /// Finds the default file to open in the archive if none was specified,
  /// searching for well-known example and README file paths in priority order.
  String? findDefaultFile(Archive archive) {
    final List<String> candidateFilenames = [
      'example/main.dart',
      'example/lib/main.dart',
      if (packageName != null) ...[
        'example/$packageName.dart',
        'example/lib/$packageName.dart',
        'example/${packageName}_example.dart',
        'example/lib/${packageName}_example.dart',
      ],
      'example/example.dart',
      'example/lib/example.dart',
      'example/example.md',
      'example/README.md',
      'example/readme.md',
      'README.md',
      'readme.md',
    ];

    for (final String candidate in candidateFilenames) {
      final ArchiveFile? file = archive.find(candidate);
      if (file != null) {
        return candidate;
      }
    }

    return null;
  }
}
