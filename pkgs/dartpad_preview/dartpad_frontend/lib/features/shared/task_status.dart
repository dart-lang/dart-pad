// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

/// The lifecycle state of a tracked application task.
enum TaskStatusOutcome { running, succeeded, failed }

/// The stable identity and default display label of a tracked task.
enum TaskKind {
  preparingWorkspace('Preparing workspace'),
  resolvingPackage('Resolving package'),
  downloadingPackage('Downloading package'),
  downloadingArchive('Downloading archive'),
  downloadingGist('Downloading gist'),
  loadingSample('Loading sample'),
  loadingDefaultSample('Loading default sample'),
  startingDartPadWorker('Starting DartPad worker'),
  creatingWorkspace('Creating workspace'),
  pubGet('Pub get'),
  pubClean('Pub clean'),
  analyzingWorkspace('Analyzing workspace'),
  startingPreview('Starting preview'),
  restartingPreview('Restarting preview'),
  stoppingPreview('Stopping preview'),
  compilingApplication('Compiling application'),
  hotReload('Hot reload'),
  compilingChanges('Compiling changes');

  const TaskKind(this.label);

  /// The label used when a task does not provide a more specific one.
  final String label;
}

/// An immutable snapshot of one tracked application task.
final class TaskStatusEntry {
  const TaskStatusEntry({
    required this.kind,
    required this.label,
    required this.startedAt,
    required this.outcome,
    required this.blocksPreview,
    this.scope,
    this.finishedAt,
  });

  /// The stable task category used by application behavior.
  final TaskKind kind;

  /// The user-facing task label.
  final String label;

  /// An optional identity within [kind], such as a path or package name.
  final String? scope;

  /// When the task started.
  final DateTime startedAt;

  /// When the task finished, or `null` while it is running.
  final DateTime? finishedAt;

  /// The current task outcome.
  final TaskStatusOutcome outcome;

  /// Whether this task must finish before compiling preview code.
  final bool blocksPreview;

  /// Whether the task is still running.
  bool get isRunning => outcome == TaskStatusOutcome.running;

  /// The elapsed or final duration at [now].
  Duration durationAt(DateTime now) => (finishedAt ?? now).difference(startedAt);

  TaskStatusEntry _finish(DateTime finishedAt, TaskStatusOutcome outcome) {
    return TaskStatusEntry(
      kind: kind,
      label: label,
      scope: scope,
      startedAt: startedAt,
      finishedAt: finishedAt,
      outcome: outcome,
      blocksPreview: blocksPreview,
    );
  }
}

/// Tracks the recent lifecycle of long-running application tasks.
///
/// Starting another task with the same kind and scope replaces the previous
/// entry. A handle belonging to the replaced entry can no longer mutate the
/// new one.
final class TaskStatusController extends ChangeNotifier {
  TaskStatusController({
    DateTime Function()? now,
    this.retention = const Duration(minutes: 5),
  }) : _now = now ?? DateTime.now;

  /// How long completed tasks remain visible.
  final Duration retention;

  final DateTime Function() _now;
  final Map<_TaskKey, _TrackedTask> _tasks = {};
  Timer? _expiryTimer;
  bool _disposed = false;

  /// Running tasks first (newest start first), then completed tasks (newest
  /// finish first).
  List<TaskStatusEntry> get entries {
    final result = _tasks.values.map((task) => task.entry).toList();
    result.sort(_compareEntries);
    return List.unmodifiable(result);
  }

  /// The task shown in the compact status summary.
  TaskStatusEntry? get current => entries.firstOrNull;

  /// Whether a running task currently blocks preview compilation.
  bool get hasBlockingPreviewTask {
    return _tasks.values.any((task) => task.entry.isRunning && task.entry.blocksPreview);
  }

  /// Starts a task and returns a handle used to finish it later.
  TaskStatusHandle startTask(
    TaskKind kind, {
    String? label,
    String? scope,
    bool blocksPreview = false,
  }) {
    if (_disposed) {
      throw StateError('Cannot start a task on a disposed controller.');
    }

    _removeExpiredTasks();
    final token = Object();
    final key = (kind: kind, scope: scope);
    _tasks[key] = _TrackedTask(
      token,
      TaskStatusEntry(
        kind: kind,
        label: label ?? kind.label,
        scope: scope,
        startedAt: _now(),
        outcome: TaskStatusOutcome.running,
        blocksPreview: blocksPreview,
      ),
    );
    _scheduleExpiry();
    notifyListeners();
    return TaskStatusHandle._(this, key, token);
  }

  /// Runs [operation] while tracking its success or failure.
  Future<T> runTask<T>(
    TaskKind kind,
    FutureOr<T> Function() operation, {
    String? label,
    String? scope,
    bool blocksPreview = false,
  }) async {
    final handle = startTask(
      kind,
      label: label,
      scope: scope,
      blocksPreview: blocksPreview,
    );
    try {
      final result = await Future<T>.sync(operation);
      handle.succeed();
      return result;
    } catch (_) {
      handle.fail();
      rethrow;
    }
  }

  void _finishTask(
    _TaskKey key,
    Object token,
    TaskStatusOutcome outcome,
  ) {
    if (_disposed) {
      return;
    }
    final task = _tasks[key];
    if (task == null || !identical(task.token, token)) {
      return;
    }
    _tasks[key] = _TrackedTask(token, task.entry._finish(_now(), outcome));
    _scheduleExpiry();
    notifyListeners();
  }

  void _cancelTask(_TaskKey key, Object token) {
    if (_disposed) {
      return;
    }
    final task = _tasks[key];
    if (task == null || !identical(task.token, token)) {
      return;
    }
    _tasks.remove(key);
    _scheduleExpiry();
    notifyListeners();
  }

  void _removeExpiredTasks() {
    final cutoff = _now().subtract(retention);
    _tasks.removeWhere((_, task) {
      final finishedAt = task.entry.finishedAt;
      return finishedAt != null && !finishedAt.isAfter(cutoff);
    });
  }

  void _scheduleExpiry() {
    _expiryTimer?.cancel();
    _expiryTimer = null;
    if (_disposed) {
      return;
    }

    DateTime? nextExpiry;
    for (final task in _tasks.values) {
      final finishedAt = task.entry.finishedAt;
      if (finishedAt == null) {
        continue;
      }
      final expiry = finishedAt.add(retention);
      if (nextExpiry == null || expiry.isBefore(nextExpiry)) {
        nextExpiry = expiry;
      }
    }
    if (nextExpiry == null) {
      return;
    }

    final delay = nextExpiry.difference(_now());
    _expiryTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (_disposed) {
        return;
      }
      _removeExpiredTasks();
      _scheduleExpiry();
      notifyListeners();
    });
  }

  static int _compareEntries(TaskStatusEntry a, TaskStatusEntry b) {
    if (a.isRunning != b.isRunning) {
      return a.isRunning ? -1 : 1;
    }
    if (a.isRunning) {
      return b.startedAt.compareTo(a.startedAt);
    }
    return b.finishedAt!.compareTo(a.finishedAt!);
  }

  @override
  void dispose() {
    _disposed = true;
    _expiryTimer?.cancel();
    _expiryTimer = null;
    _tasks.clear();
    super.dispose();
  }
}

/// A capability for finishing one specific task run.
final class TaskStatusHandle {
  TaskStatusHandle._(this._controller, this._key, this._token);

  final TaskStatusController _controller;
  final _TaskKey _key;
  final Object _token;
  bool _finished = false;

  /// Marks the task as successful.
  void succeed() => _finish(TaskStatusOutcome.succeeded);

  /// Marks the task as failed.
  void fail() => _finish(TaskStatusOutcome.failed);

  /// Removes an externally-driven task without recording an outcome.
  void cancel() {
    if (_finished) {
      return;
    }
    _finished = true;
    _controller._cancelTask(_key, _token);
  }

  void _finish(TaskStatusOutcome outcome) {
    if (_finished) {
      return;
    }
    _finished = true;
    _controller._finishTask(_key, _token, outcome);
  }
}

typedef _TaskKey = ({TaskKind kind, String? scope});

final class _TrackedTask {
  const _TrackedTask(this.token, this.entry);

  final Object token;
  final TaskStatusEntry entry;
}

/// Formats a task duration for compact status UI.
String formatTaskDuration(Duration duration) {
  final milliseconds = duration.isNegative ? 0 : duration.inMilliseconds;
  if (milliseconds < Duration.millisecondsPerMinute) {
    return '${(milliseconds / Duration.millisecondsPerSecond).toStringAsFixed(1)}s';
  }

  final totalSeconds = milliseconds ~/ Duration.millisecondsPerSecond;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  final totalMinutes = totalSeconds ~/ Duration.secondsPerMinute;
  if (totalMinutes < Duration.minutesPerHour) {
    return '${totalMinutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  final hours = totalMinutes ~/ Duration.minutesPerHour;
  final minutes = totalMinutes % Duration.minutesPerHour;
  return '${hours}h ${minutes.toString().padLeft(2, '0')}m ${seconds.toString().padLeft(2, '0')}s';
}
