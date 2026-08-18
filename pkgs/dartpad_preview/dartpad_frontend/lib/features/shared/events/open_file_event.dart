// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../app_event_bus.dart';

/// Request to open a file in the editor and optionally navigate to a specific position.
final class OpenFileEvent extends AppEvent {
  const OpenFileEvent(
    this.path, {
    this.line,
    this.column,
  });

  /// The relative workspace file path (e.g. 'lib/main.dart').
  final String path;

  /// 1-based line number in the file, or `null` if no position is specified.
  final int? line;

  /// 1-based column number in the file, or `null` if no position is specified.
  final int? column;
}
