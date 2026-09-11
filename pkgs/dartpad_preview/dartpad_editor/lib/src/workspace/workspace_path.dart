// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

/// The path context for virtual workspace paths, which always use `/`.
final p.Context workspacePath = p.posix;

/// Normalizes a workspace [path].
///
/// The workspace root is represented by an empty string instead of `.`.
String normalizeWorkspacePath(String path) {
  final normalized = workspacePath.normalize(path);
  return normalized == '.' ? '' : normalized;
}

/// Returns the final path segment of a workspace [path].
String basenameWorkspacePath(String path) {
  return workspacePath.basename(normalizeWorkspacePath(path));
}

/// Returns the workspace-relative parent folder of [path].
///
/// The workspace root is represented by an empty string.
String parentWorkspacePath(String path) {
  return normalizeWorkspacePath(
    workspacePath.dirname(normalizeWorkspacePath(path)),
  );
}

/// Joins [folder] and [child] into a normalized workspace path.
String joinWorkspacePath(String folder, String child) {
  return normalizeWorkspacePath(
    workspacePath.join(normalizeWorkspacePath(folder), child),
  );
}

/// Whether [path] identifies [folder] itself or one of its descendants.
bool isWithinWorkspaceFolder(String path, String folder) {
  final normalizedPath = normalizeWorkspacePath(path);
  final normalizedFolder = normalizeWorkspacePath(folder);
  if (!_isWorkspaceRelativePath(normalizedPath) || !_isWorkspaceRelativePath(normalizedFolder)) {
    return false;
  }
  return normalizedFolder.isEmpty ||
      normalizedPath == normalizedFolder ||
      workspacePath.isWithin(normalizedFolder, normalizedPath);
}

bool _isWorkspaceRelativePath(String path) {
  return !workspacePath.isAbsolute(path) && !workspacePath.split(path).contains('..');
}

/// Replaces the [sourceFolder] prefix of [path] with [destinationFolder].
///
/// Returns the normalized [path] unchanged when it is outside [sourceFolder].
String rebaseWorkspacePath(
  String path,
  String sourceFolder,
  String destinationFolder,
) {
  final normalizedPath = normalizeWorkspacePath(path);
  final normalizedSource = normalizeWorkspacePath(sourceFolder);
  final normalizedDestination = normalizeWorkspacePath(destinationFolder);
  if (!isWithinWorkspaceFolder(normalizedPath, normalizedSource)) {
    return normalizedPath;
  }
  if (normalizedPath == normalizedSource) {
    return normalizedDestination;
  }
  return joinWorkspacePath(
    normalizedDestination,
    workspacePath.relative(normalizedPath, from: normalizedSource),
  );
}
