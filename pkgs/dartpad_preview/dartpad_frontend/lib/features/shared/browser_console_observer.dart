// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_event_bus.dart';
import 'events/log_event.dart';

/// Forwards [LogEvent]s from the [AppEventBus] to the browser's developer
/// console.
///
/// Takes an [AppEventBus] to subscribe to log events.
final class BrowserConsoleObserver {
  BrowserConsoleObserver(AppEventBus events) {
    _subscription = events.on<LogEvent>().listen(_write);
  }

  late final StreamSubscription<LogEvent> _subscription;

  void _write(LogEvent event) {
    final suffix = [
      if (event.error != null) event.error,
      if (event.stackTrace != null) event.stackTrace,
    ].join('\n');
    final message = '[dartpad_preview] ${event.message}${suffix.isEmpty ? '' : '\n$suffix'}'.toJS;
    web.console.log(message);
  }

  void dispose() {
    _subscription.cancel();
  }
}
