// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:path/path.dart' as p;

/// The path context for virtual workspace paths, which always use `/`.
final p.Context workspacePath = p.posix;

/// Normalizes a workspace [path], returning an empty string for the current directory (`.`).
String normalizeWorkspacePath(String path) {
  final normalized = workspacePath.normalize(path);
  return normalized == '.' ? '' : normalized;
}
