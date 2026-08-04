// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

import '../app_event_bus.dart';

/// Output produced by a project-facing tool, such as `pub get` or a runner.
/// - [message]: human-readable log text.
/// - [level]: severity level; defaults to [Level.INFO].
/// - [error]: optional error object associated with this entry.
/// - [stackTrace]: optional stack trace accompanying [error].
/// These events are displayed in the application's debug console.
final class LogEvent extends AppEvent {
  const LogEvent(
    this.message, {
    this.level = Level.INFO,
    this.error,
    this.stackTrace,
  });

  /// Raw output text. It may contain multiple lines.
  final String message;

  /// Severity level; defaults to [Level.INFO].
  final Level level;

  /// Optional error object associated with this log entry.
  final Object? error;

  /// Optional stack trace accompanying [error].
  final StackTrace? stackTrace;
}
