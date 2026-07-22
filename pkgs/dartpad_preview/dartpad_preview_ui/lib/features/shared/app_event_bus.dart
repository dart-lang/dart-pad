// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';

/// Base type for all events dispatched through the [AppEventBus].
sealed class AppEvent {
  const AppEvent();
}

/// A command that carries its own [Completer] so dispatchers can `await`
/// the handler's result.
abstract class AsyncCommandBase<T> extends AppEvent {
  AsyncCommandBase() : _completer = Completer<T>();

  final Completer<T> _completer;
  Future<T> get future => _completer.future;

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}

/// An async command that resolves with a value of type [T].
abstract class AsyncCommand<T> extends AsyncCommandBase<T> {
  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}

/// An async command that completes without a return value.
abstract class VoidAsyncCommand extends AsyncCommandBase<void> {
  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

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

/// Lightweight, broadcast-based event bus for decoupled communication
/// between application components.
final class AppEventBus {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  Stream<T> on<T extends AppEvent>() => _controller.stream.where((event) => event is T).cast<T>();

  void dispatch(AppEvent event) => _controller.add(event);

  Future<T> dispatchAsync<T>(AsyncCommandBase<T> command) {
    dispatch(command);
    return command.future;
  }

  Future<void> dispose() => _controller.close();
}
