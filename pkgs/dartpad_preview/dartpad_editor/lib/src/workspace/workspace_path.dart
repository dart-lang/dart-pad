// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

/// The path context for virtual workspace paths, which always use `/`.
final p.Context workspacePath = p.posix;

/// The singleton [WorkspaceContext] instance for workspace path manipulation.
final WorkspaceContext workspaceContext = WorkspaceContext._();

/// Utility class for working with virtual workspace paths.
///
/// Provides path manipulation functions such as normalization, joining, rebase,
/// parent directory detection, and visibility filtering for virtual workspace resources.
class WorkspaceContext {
  WorkspaceContext._();

  /// Normalizes a workspace [path], returning an empty string for the current directory (`.`).
  String normalize(String path) {
    final normalized = workspacePath.normalize(path);
    return normalized == '.' ? '' : normalized;
  }

  /// Returns the final path segment of [value].
  String basename(String value) => workspacePath.basename(normalize(value));

  /// Returns the workspace-relative parent folder of [value].
  ///
  /// The workspace root is represented by an empty string.
  String dirname(String value) {
    final result = workspacePath.dirname(normalize(value));
    return result == '.' ? '' : result;
  }

  /// Joins [folder] and [name] into a normalized workspace path.
  String join(String folder, String name) {
    return normalize(
      workspacePath.join(normalize(folder), name),
    );
  }

  /// Whether [value] identifies [folder] itself or one of its descendants.
  bool isWithinFolder(String value, String folder) {
    final normalizedValue = normalize(value);
    final normalizedFolder = normalize(folder);
    return normalizedFolder.isEmpty ||
        normalizedValue == normalizedFolder ||
        workspacePath.isWithin(normalizedFolder, normalizedValue);
  }

  /// Replaces the [sourceFolder] prefix of [value] with [destinationFolder].
  ///
  /// Returns the normalized [value] unchanged when it is outside
  /// [sourceFolder].
  String rebasePath(String value, String sourceFolder, String destinationFolder) {
    final normalizedValue = normalize(value);
    final normalizedOldRoot = normalize(sourceFolder);
    final normalizedNewRoot = normalize(destinationFolder);
    if (normalizedValue == normalizedOldRoot) {
      return normalizedNewRoot;
    }
    return workspacePath.join(
      normalizedNewRoot,
      workspacePath.relative(normalizedValue, from: normalizedOldRoot),
    );
  }

  /// Whether [value] should be shown in the workspace file tree.
  ///
  /// The workspace root and generated `.dart_tool` and `build` subtrees are
  /// hidden.
  bool isVisiblePath(String value) {
    final normalized = normalize(value);
    if (normalized.isEmpty) {
      return false;
    }
    return normalized
        .split('/')
        .every(
          (segment) => segment.isNotEmpty && segment != '.dart_tool' && segment != 'build',
        );
  }
}
