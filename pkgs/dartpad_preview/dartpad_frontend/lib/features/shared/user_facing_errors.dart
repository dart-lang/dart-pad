// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

/// Returns a stable, user-facing message without exposing internal exception
/// formatting.
String userFacingErrorMessage(
  Object error, {
  required String fallback,
}) {
  return switch (error) {
    WorkspaceResourceConflictException(:final targetPath) => 'A file or folder already exists at "$targetPath".',
    _ => fallback,
  };
}
