// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';

/// A file that can be imported into the virtual workspace.
final class ProjectFile {
  const ProjectFile({required this.path, required this.bytes});

  /// The workspace-relative file path.
  final String path;

  /// The file contents.
  final Uint8List bytes;
}

/// A temporary collection of loaded files for project resolution and import.
///
/// Retains the supplied byte buffers without copying them. Once imported, the
/// workspace owns the current files and this collection need not be retained.
final class Project {
  /// Collects [files] and copies the optional gist [pathMapping].
  ///
  /// File paths are normalized with [ProjectLoader.normalizePath]. Invalid paths
  /// or multiple files resolving to the same path throw an [ArgumentError].
  Project(Iterable<ProjectFile> files, {Map<String, String> pathMapping = const {}})
    : pathMapping = Map.unmodifiable(pathMapping) {
    for (final file in files) {
      final path = ProjectLoader.normalizePath(file.path);
      if (_files.containsKey(path)) {
        throw ArgumentError('Multiple files resolve to the same path: $path');
      }
      _files[path] = file.bytes;
    }
  }

  final Map<String, Uint8List> _files = {};

  /// An unmodifiable mapping from original source paths to workspace paths.
  ///
  /// Only the gist loader supplies this mapping: it moves root-level Dart files
  /// into `lib/`, for example `main.dart` to `lib/main.dart`, and maps other files
  /// to their unchanged paths. Archives, packages, and samples use an empty map
  /// and preserve their directory structure. Mapping keys and values are
  /// normalized paths.
  final Map<String, String> pathMapping;

  /// Normalizes a source [path] and returns its mapped workspace path, if any.
  ///
  /// Only gist projects use [pathMapping] to account for root-level Dart files
  /// moved into `lib/`. For archives, packages, and samples, this simply returns
  /// the normalized path. Does not check whether the target file exists.
  /// Invalid source paths throw an [ArgumentError].
  String resolvePath(String path) {
    final normalized = ProjectLoader.normalizePath(path);
    return pathMapping[normalized] ?? normalized;
  }

  /// The normalized workspace-relative paths in this project.
  ///
  /// Returns an unmodifiable snapshot in file insertion order.
  Iterable<String> get paths => List.unmodifiable(_files.keys);

  /// The current files in insertion order, produced lazily when iterated.
  ///
  /// Each returned file references the stored byte buffer without copying it.
  Iterable<ProjectFile> get files => _files.entries.map(
    (entry) => ProjectFile(path: entry.key, bytes: entry.value),
  );

  /// Whether a file exists at the normalized workspace-relative [path].
  ///
  /// Invalid paths throw an [ArgumentError].
  bool containsFile(String path) {
    return _files.containsKey(ProjectLoader.normalizePath(path));
  }

  /// Returns the stored byte buffer at the workspace-relative [path].
  ///
  /// Returns `null` when the file does not exist. Invalid paths throw an
  /// [ArgumentError]. The returned bytes are shared with this project.
  Uint8List? readFile(String path) => _files[ProjectLoader.normalizePath(path)];

  /// Adds or replaces a file at the workspace-relative [path] with [bytes].
  ///
  /// Retains the buffer without copying it. Invalid paths throw an [ArgumentError].
  void writeFile(String path, Uint8List bytes) {
    _files[ProjectLoader.normalizePath(path)] = bytes;
  }
}

/// Resolves [packageRoot] to the editor and language-server root URI.
///
/// [rootWorkspaceUri] identifies the complete virtual workspace, while
/// [packageRoot] is a workspace-relative path. A missing package root or a
/// package rooted at the workspace both use [rootWorkspaceUri] directly.
Uri resolveEditorRootUri(Uri rootWorkspaceUri, String? packageRoot) {
  if (packageRoot == null || packageRoot.isEmpty) {
    return rootWorkspaceUri;
  }

  final normalizedPackageRoot = normalizeWorkspacePath(packageRoot);
  return rootWorkspaceUri.resolveUri(
    Uri(path: '$normalizedPackageRoot/'),
  );
}

/// Shared workspace import operations for externally loaded projects.
final class ProjectLoader {
  /// Finds the nearest parent directory of [entryPath] containing pubspec.yaml.
  ///
  /// Returns null when no project root can be inferred.
  static String? findProjectDirectory(
    Project project,
    String entryPath,
  ) {
    final segments = normalizePath(entryPath).split('/');

    for (var i = segments.length - 1; i >= 0; i--) {
      final parentDirectory = segments.sublist(0, i).join('/');
      final pubspecPath = joinWorkspacePath(parentDirectory, 'pubspec.yaml');
      if (project.containsFile(pubspecPath)) {
        return parentDirectory;
      }
    }

    return null;
  }

  /// Creates all folders and writes [project] into [root].
  static Future<void> writeFiles(
    WorkspaceFolder root,
    Project project,
  ) async {
    final folders = <String>{};
    for (final file in project.files) {
      var directory = parentWorkspacePath(file.path);
      while (directory.isNotEmpty) {
        folders.add(directory);
        directory = parentWorkspacePath(directory);
      }
    }

    final sortedFolders = folders.toList()..sort((a, b) => a.length.compareTo(b.length));
    for (final folder in sortedFolders) {
      await root.getFolder(folder).create();
    }

    for (final file in project.files) {
      await root.workspace.writeFileFromBytes(
        root.getFile(file.path).path,
        file.bytes,
      );
    }
  }

  /// Normalizes [path] and verifies that it remains inside the workspace.
  static String normalizePath(String path, {bool allowRoot = false}) {
    final normalized = normalizeWorkspacePath(path);
    if ((!allowRoot && normalized.isEmpty) ||
        workspacePath.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw ArgumentError('Path must be relative to the workspace: $path');
    }
    return normalized;
  }
}
