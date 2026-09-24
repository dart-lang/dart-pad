// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';
import '../../shared/log_source.dart';
import '../models/console_entry.dart';

/// Collects application log events for display in the console.
class ConsoleViewModel extends ChangeNotifier {
  ConsoleViewModel({required AppEventBus events}) {
    _subscription = events.on<LogEvent>().listen(_handleLog);
  }

  final List<ConsoleEntry> _logs = [];
  bool _hasErrors = false;
  late final StreamSubscription<LogEvent> _subscription;

  /// The collected log lines, in arrival order.
  List<ConsoleEntry> get logs => List.unmodifiable(_logs);

  /// Whether a displayed log line has a level above warning.
  bool get hasErrors => _hasErrors;

  void _handleLog(LogEvent event) {
    var changed = _appendLogText(event.message, event.level, event.source, event.isApplicationOutput);

    if (event.error case final error?) {
      changed |= _appendLogText(error.toString(), event.level, event.source, event.isApplicationOutput);
    }
    if (event.stackTrace case final stackTrace?) {
      changed |= _appendLogText(stackTrace.toString(), event.level, event.source, event.isApplicationOutput);
    }

    if (changed) {
      notifyListeners();
    }
  }

  bool _appendLogText(String text, Level level, LogSource source, bool isApplicationOutput) {
    var changed = false;
    for (final line in _splitLogLines(text)) {
      _logs.add(
        ConsoleEntry(
          message: line,
          level: level,
          source: source,
          isApplicationOutput: isApplicationOutput,
        ),
      );
      changed = true;
    }
    if (changed && level > Level.WARNING) {
      _hasErrors = true;
    }
    return changed;
  }

  /// Removes all displayed logs.
  void clear() {
    if (_logs.isEmpty) {
      return;
    }
    _logs.clear();
    _hasErrors = false;
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
