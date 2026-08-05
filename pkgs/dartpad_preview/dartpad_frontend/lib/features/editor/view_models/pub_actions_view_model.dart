// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';
import 'package:logging/logging.dart';

import '../../shared/app_event_bus.dart';
import '../../shared/events/log_event.dart';

/// Coordinates path-aware Pub actions initiated from the editor.
final class PubActionsViewModel extends ChangeNotifier {
  /// Creates Pub actions backed by the supplied editor and workspace callbacks.
  PubActionsViewModel({
    required this.saveAllFiles,
    required this.events,
    required this.pubGetAction,
    required this.pubCleanAction,
  });

  /// Persists all open editor files before Pub resolves dependencies.
  final Future<void> Function() saveAllFiles;

  /// Event bus used to report Pub failures to the debug console.
  final AppEventBus events;

  /// Resolves dependencies in the supplied workspace-relative directory.
  final Future<void> Function(String path) pubGetAction;

  /// Removes generated output in the supplied workspace-relative directory.
  final Future<void> Function(String path) pubCleanAction;

  bool _busy = false;

  /// Whether a Pub action is currently running.
  bool get busy => _busy;

  /// Saves all files and runs Pub Get in [path].
  Future<void> pubGet(String path) async {
    await _run('Pub get failed.', () async {
      try {
        await saveAllFiles();
      } catch (_) {
        // The editor owns and displays save failures.
        return;
      }
      await pubGetAction(path);
    });
  }

  /// Runs Pub Clean in [path] without saving files first.
  Future<void> pubClean(String path) async {
    await _run('Pub clean failed.', () => pubCleanAction(path));
  }

  Future<void> _run(
    String failureMessage,
    Future<void> Function() operation,
  ) async {
    if (_busy) {
      return;
    }
    _busy = true;
    notifyListeners();
    try {
      await operation();
    } catch (error, stackTrace) {
      events.dispatch(
        LogEvent(
          failureMessage,
          level: Level.SEVERE,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}
