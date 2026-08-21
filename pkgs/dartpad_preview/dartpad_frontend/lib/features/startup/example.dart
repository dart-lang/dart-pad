// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Metadata for a packaged example project (snippet or sample).
class Example {
  final String name;
  final String id;
  final String archivePath;
  final String entryPath;

  const Example({
    required this.name,
    required this.id,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '$name ($id)';
}
