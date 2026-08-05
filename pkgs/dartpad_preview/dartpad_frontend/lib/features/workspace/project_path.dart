// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

/// Returns [path] relative to [projectRoot] for display to the user.
///
/// The project root itself is displayed as `/`.
String projectRelativeDisplayPath({
  required String path,
  required String projectRoot,
}) {
  final normalizedPath = workspaceContext.normalize(path);
  final normalizedRoot = workspaceContext.normalize(projectRoot);

  if (normalizedPath == normalizedRoot) {
    return '/';
  }
  if (normalizedRoot.isNotEmpty && normalizedPath.startsWith('$normalizedRoot/')) {
    return normalizedPath.substring(normalizedRoot.length + 1);
  }
  if (normalizedRoot.isNotEmpty) {
    return workspacePath.relative(normalizedPath, from: normalizedRoot);
  }
  return normalizedPath.isEmpty ? '/' : normalizedPath;
}
