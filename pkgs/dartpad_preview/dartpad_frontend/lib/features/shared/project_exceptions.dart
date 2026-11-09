// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A project path that is absolute, escapes the project, or does not exist in it.
final class ProjectPathException extends ArgumentError {
  ProjectPathException(super.message);
}

/// A project source that is unavailable or returned an error status or unusable data.
final class ProjectSourceException implements Exception {
  const ProjectSourceException(this.message);

  final String message;
}

/// A project file whose content is malformed, such as a pubspec that is not a YAML mapping.
final class ProjectContentException extends FormatException {
  const ProjectContentException(super.message);
}

/// Saved project data that is missing, corrupt, or no longer restorable.
final class ProjectStorageException implements Exception {
  const ProjectStorageException(this.message);

  final String message;
}
