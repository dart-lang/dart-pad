// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

/// Lightweight, broadcast-based event bus for decoupled communication
/// between application components.
final class AppEventBus {
  final StreamController<AppEvent> _controller = StreamController<AppEvent>.broadcast();

  Stream<T> on<T extends AppEvent>() => _controller.stream.where((event) => event is T).cast<T>();

  void dispatch(AppEvent event) => _controller.add(event);

  Future<T> dispatchAsync<T>(AsyncEventBase<T> command) {
    dispatch(command);
    return command.future;
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

/// Base type for all events dispatched through the [AppEventBus].
class AppEvent {
  const AppEvent();
}

/// An event that carries its own [Completer] so dispatchers can `await`
/// the handler's result.
abstract class AsyncEventBase<T> extends AppEvent {
  AsyncEventBase() : _completer = Completer<T>();

  final Completer<T> _completer;
  Future<T> get future => _completer.future;

  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(error, stackTrace);
    }
  }
}

/// An event that resolves with a value of type [T].
abstract class AsyncEvent<T> extends AsyncEventBase<T> {
  void complete(T value) {
    if (!_completer.isCompleted) {
      _completer.complete(value);
    }
  }
}

/// An event that completes without a return value.
abstract class VoidAsyncEvent extends AsyncEventBase<void> {
  void complete() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }
}
