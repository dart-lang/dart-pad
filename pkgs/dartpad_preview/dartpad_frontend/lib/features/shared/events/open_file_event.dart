// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../app_event_bus.dart';

/// Fired when a request is made to open a file at a specific line and column.
final class OpenFileEvent extends AppEvent {
  const OpenFileEvent(
    this.path, {
    required this.line,
    required this.column,
  });

  final String path;
  final int line;
  final int column;
}
