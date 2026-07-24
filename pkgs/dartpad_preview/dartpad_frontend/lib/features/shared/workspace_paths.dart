// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

final p.Context _workspacePath = p.posix;

/// Normalizes [value] as a workspace-relative POSIX path.
///
/// The workspace root is represented by an empty string.
String normalizeWorkspacePath(String value) {
  final normalized = _workspacePath.normalize(value);
  return normalized == '.' ? '' : normalized;
}

/// Returns the final path segment of [value].
String workspaceBasename(String value) => _workspacePath.basename(normalizeWorkspacePath(value));

/// Returns the workspace-relative parent folder of [value].
///
/// The workspace root is represented by an empty string.
String workspaceDirname(String value) {
  final result = _workspacePath.dirname(normalizeWorkspacePath(value));
  return result == '.' ? '' : result;
}

/// Joins [folder] and [name] into a normalized workspace path.
String joinWorkspacePath(String folder, String name) {
  return normalizeWorkspacePath(
    _workspacePath.join(normalizeWorkspacePath(folder), name),
  );
}

/// Whether [value] identifies [folder] itself or one of its descendants.
bool isWithinWorkspaceFolder(String value, String folder) {
  final normalizedValue = normalizeWorkspacePath(value);
  final normalizedFolder = normalizeWorkspacePath(folder);
  return normalizedValue == normalizedFolder || _workspacePath.isWithin(normalizedFolder, normalizedValue);
}

/// Replaces the [sourceFolder] prefix of [value] with [destinationFolder].
///
/// Returns the normalized [value] unchanged when it is outside
/// [sourceFolder].
String rebaseWorkspacePath(
  String value,
  String sourceFolder,
  String destinationFolder,
) {
  final normalizedValue = normalizeWorkspacePath(value);
  final normalizedSource = normalizeWorkspacePath(sourceFolder);
  if (!isWithinWorkspaceFolder(normalizedValue, normalizedSource)) {
    return normalizedValue;
  }
  if (normalizedValue == normalizedSource) {
    return normalizeWorkspacePath(destinationFolder);
  }
  return joinWorkspacePath(
    destinationFolder,
    _workspacePath.relative(normalizedValue, from: normalizedSource),
  );
}

/// Whether [value] should be shown in the workspace file tree.
///
/// The workspace root and generated `.dart_tool` and `build` subtrees are
/// hidden.
bool isVisibleWorkspacePath(String value) {
  final normalized = normalizeWorkspacePath(value);
  if (normalized.isEmpty) {
    return false;
  }
  return normalized
      .split('/')
      .every(
        (segment) => segment.isNotEmpty && segment != '.dart_tool' && segment != 'build',
      );
}
