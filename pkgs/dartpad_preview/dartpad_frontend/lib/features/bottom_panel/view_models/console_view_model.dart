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
  bool _hasErrors = false;
  late final StreamSubscription<LogEvent> _subscription;

  /// The collected log lines, in arrival order.
  List<ConsoleEntry> get logs => List.unmodifiable(_logs);

  /// Whether a displayed log line has a level above warning.
  bool get hasErrors => _hasErrors;

  /// The console scroll position while it does not follow new output, kept so
  /// a remounted console returns to it. `null` while the console follows.
  double? scrollTop;

  void _handleLog(LogEvent event) {
    var changed = _appendLogText(event.message, event);

    if (event.error case final error?) {
      changed |= _appendLogText(error.toString(), event);
    }
    if (event.stackTrace case final stackTrace?) {
      changed |= _appendLogText(stackTrace.toString(), event);
    }

    if (changed) {
      notifyListeners();
    }
  }

  bool _appendLogText(String text, LogEvent event) {
    var changed = false;
    for (final line in _splitLogLines(text)) {
      _logs.add(ConsoleEntry(message: line, level: event.level, source: event));
      changed = true;
    }
    if (changed && event.level > Level.WARNING) {
      _hasErrors = true;
    }
    return changed;
  }

  /// The index of the first line displayed for [event], or `null` when that
  /// event has no displayed lines, for example after [clear].
  int? indexOf(LogEvent event) {
    final index = _logs.indexWhere((entry) => identical(entry.source, event));
    return index < 0 ? null : index;
  }

  /// Removes all displayed logs.
  void clear() {
    if (_logs.isEmpty) {
      return;
    }
    _logs.clear();
    _hasErrors = false;
    scrollTop = null;
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
