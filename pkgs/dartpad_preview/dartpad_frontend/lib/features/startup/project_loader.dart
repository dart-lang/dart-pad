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

/// The workspace state produced by a project loader.
///
/// [projectDir] is the folder shown in the file tree. [packageRoot] is null
/// when the loaded files do not form a Dart package; it is an empty string for
/// a package rooted at the workspace root.
final class LoadedProject {
  const LoadedProject({
    required this.projectDir,
    required this.entryPath,
    required this.packageRoot,
  });

  final String projectDir;
  final String? entryPath;
  final String? packageRoot;
}

/// Shared workspace import operations for externally loaded projects.
final class ProjectLoader {
  /// Finds the nearest parent directory of [entryPath] containing pubspec.yaml.
  ///
  /// Returns null when no project root can be inferred.
  static String? findProjectDirectory(
    Iterable<ProjectFile> files,
    String entryPath,
  ) {
    final filePaths = files.map((file) => normalizePath(file.path)).toSet();
    final segments = normalizePath(entryPath).split('/');

    for (var i = segments.length - 1; i >= 0; i--) {
      final parentDirectory = segments.sublist(0, i).join('/');
      final pubspecPath = parentDirectory.isEmpty ? 'pubspec.yaml' : '$parentDirectory/pubspec.yaml';
      if (filePaths.contains(pubspecPath)) {
        return parentDirectory;
      }
    }

    return null;
  }

  /// Creates all folders and writes [files] into [root].
  static Future<void> writeFiles(
    WorkspaceFolder root,
    Iterable<ProjectFile> files,
  ) async {
    final normalizedFiles = <ProjectFile>[];
    final paths = <String>{};

    for (final file in files) {
      final path = normalizePath(file.path);
      if (!paths.add(path)) {
        throw ArgumentError('Multiple files resolve to the same path: $path');
      }
      normalizedFiles.add(ProjectFile(path: path, bytes: file.bytes));
    }

    final folders = <String>{};
    for (final file in normalizedFiles) {
      var directory = workspaceContext.dirname(file.path);
      while (directory.isNotEmpty) {
        folders.add(directory);
        directory = workspaceContext.dirname(directory);
      }
    }

    final sortedFolders = folders.toList()..sort((a, b) => a.length.compareTo(b.length));
    for (final folder in sortedFolders) {
      await root.getFolder(folder).create();
    }

    for (final file in normalizedFiles) {
      await root.workspace.writeFileFromBytes(
        root.getFile(file.path).path,
        file.bytes,
      );
    }
  }

  /// Normalizes [path] and verifies that it remains inside the workspace.
  static String normalizePath(String path) {
    final normalized = workspaceContext.normalize(path);
    if (normalized.isEmpty ||
        workspacePath.isAbsolute(normalized) ||
        normalized == '..' ||
        normalized.startsWith('../')) {
      throw ArgumentError('Path must be relative to the workspace: $path');
    }
    return normalized;
  }
}
