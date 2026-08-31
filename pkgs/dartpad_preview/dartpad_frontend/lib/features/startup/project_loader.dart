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
final class LoadedProject {
  const LoadedProject({
    required this.projectDir,
    required this.entryPath,
    required this.packageRoot,
    this.pathToMain,
  });

  /// Workspace-relative folder shown as the root of the file tree.
  final String projectDir;

  /// Workspace-relative file opened after the project is loaded.
  final String? entryPath;

  /// Workspace-relative root of the Dart package containing [entryPath].
  ///
  /// This is `null` when no Dart package was detected and an empty string when
  /// the package is rooted at the complete workspace.
  final String? packageRoot;

  /// Workspace-relative Dart entrypoint executed in the preview.
  final String? pathToMain;
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

  final normalizedPackageRoot = workspaceContext.normalize(packageRoot);
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
