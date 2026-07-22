// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:logging/logging.dart';

sealed class AppEvent {
  const AppEvent();
}

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

abstract class AsyncCommand<T> extends AsyncCommandBase<T> {
  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}

abstract class VoidAsyncCommand extends AsyncCommandBase<void> {
  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}

final class LogEvent extends AppEvent {
  const LogEvent(
    this.message, {
    this.level = Level.INFO,
    this.error,
    this.stackTrace,
  });

  final String message;
  final Level level;
  final Object? error;
  final StackTrace? stackTrace;
}

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
