// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A preview entrypoint that does not exist in the workspace.
final class PreviewEntrypointException implements Exception {
  const PreviewEntrypointException(this.message);

  final String message;

  @override
  String toString() => message;
}
