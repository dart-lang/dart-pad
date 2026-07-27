// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

import '../app_event_bus.dart';

/// A structured log message routed through the event bus.
///
/// - [message]: human-readable log text.
/// - [level]: severity level; defaults to [Level.INFO].
/// - [error]: optional error object associated with this entry.
/// - [stackTrace]: optional stack trace accompanying [error].
final class LogEvent extends AppEvent {
  const LogEvent(
    this.message, {
    this.level = Level.INFO,
    this.error,
    this.stackTrace,
  });

  /// Human-readable log text.
  final String message;

  /// Severity level; defaults to [Level.INFO].
  final Level level;

  /// Optional error object associated with this log entry.
  final Object? error;

  /// Optional stack trace accompanying [error].
  final StackTrace? stackTrace;
}
