// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Metadata for a packaged example project (snippet or sample).
class Example {
  /// The display name of the example.
  final String name;

  /// The unique identifier of the example.
  final String id;

  /// The optional category divider shown before the example.
  final String? subcategory;

  /// The optional icon displayed for the example.
  final String? icon;

  /// The path to the packaged archive containing the example project.
  final String archivePath;

  /// The relative path to the main entry file within the example project.
  final String entryPath;

  const Example({
    required this.name,
    required this.id,
    this.subcategory,
    this.icon,
    required this.archivePath,
    required this.entryPath,
  });

  @override
  String toString() => '$name ($id)';
}
