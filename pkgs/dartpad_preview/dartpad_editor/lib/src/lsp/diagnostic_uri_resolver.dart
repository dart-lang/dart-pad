// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../workspace/workspace_path.dart';

/// Resolves an LSP diagnostic URI to a workspace-relative file path.
///
/// If [workspaceFolder] is provided, the URI is resolved relative to it.
/// Otherwise, the last path segment is returned as a fallback.
String pathFromDiagnosticUri(String uri, {Uri? workspaceFolder}) {
  final workspacePath = _pathWithinWorkspace(uri, workspaceFolder);
  if (workspacePath != null) {
    return workspacePath;
  }

  return Uri.decodeFull(uri.split('/').last);
}

String? _pathWithinWorkspace(String uri, Uri? workspaceFolder) {
  if (workspaceFolder == null) {
    return null;
  }

  final parsedUri = Uri.tryParse(uri);
  if (parsedUri == null) {
    return null;
  }

  final workspacePath = workspaceFolder.path.endsWith('/') ? workspaceFolder.path : '${workspaceFolder.path}/';
  final isSameLocation = parsedUri.scheme == workspaceFolder.scheme && parsedUri.authority == workspaceFolder.authority;
  if (isSameLocation && parsedUri.path.startsWith(workspacePath)) {
    final relativePath = parsedUri.path.substring(workspacePath.length);
    return normalizeWorkspacePath(Uri.decodeFull(relativePath));
  }

  return null;
}
