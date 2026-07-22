import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_event_bus.dart';

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

  Future<void> dispose() => _subscription.cancel();
}
