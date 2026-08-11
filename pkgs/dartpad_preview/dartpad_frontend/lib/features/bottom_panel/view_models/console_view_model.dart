// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../models/console_entry.dart';

/// Collects application log events for display in the console.
class ConsoleViewModel extends ChangeNotifier {
  ConsoleViewModel({required AppEventBus events}) {
    _subscription = events.on<LogEvent>().listen(_handleLog);
  }

  final List<ConsoleEntry> _logs = [];
  late final StreamSubscription<LogEvent> _subscription;

  /// The collected log lines, in arrival order.
  List<ConsoleEntry> get logs => List.unmodifiable(_logs);

  void _handleLog(LogEvent event) {
    var changed = _appendLogText(event.message, event.level);

    if (event.error case final error?) {
      changed |= _appendLogText(error.toString(), event.level);
    }
    if (event.stackTrace case final stackTrace?) {
      changed |= _appendLogText(stackTrace.toString(), event.level);
    }

    if (changed) {
      notifyListeners();
    }
  }

  bool _appendLogText(String text, Level level) {
    var changed = false;
    for (final line in _splitLogLines(text)) {
      _logs.add(ConsoleEntry(message: line, level: level));
      changed = true;
    }
    return changed;
  }

  /// Removes all displayed logs.
  void clear() {
    if (_logs.isEmpty) {
      return;
    }
    _logs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}

/// Splits raw log text while preserving indentation and internal empty lines.
Iterable<String> _splitLogLines(String rawLog) sync* {
  if (rawLog.isEmpty) {
    return;
  }

  final lines = rawLog.split(RegExp(r'\r?\n'));
  final end = lines.last.isEmpty ? lines.length - 1 : lines.length;
  yield* lines.take(end);
}
