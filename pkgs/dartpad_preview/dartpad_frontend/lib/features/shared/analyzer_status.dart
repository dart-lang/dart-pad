// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'task_status.dart';

/// Tracks analyzer readiness and translates LSP analysis activity into
/// application tasks.
///
/// Analyzer startup and the first complete analysis are represented by a
/// [TaskKind.startingAnalyzer] task. Later analysis cycles trigger a
/// [TaskKind.analyzing] task which reuses the same task key, replacing earlier
/// analysis entries in recent task history.
///
/// [idleDebounce] defines how long the controller waits after receiving an
/// `isAnalyzing: false` event before completing active analysis tasks. This
/// avoids flickering when the analyzer repeatedly transitions between busy and
/// idle in quick succession (e.g. while indexing multiple files during reference
/// search).
final class AnalyzerStatusController {
  AnalyzerStatusController(
    this._taskStatus, {
    this.idleDebounce = const Duration(milliseconds: 50),
  });

  final TaskStatusController _taskStatus;

  /// The delay before marking active analysis tasks as succeeded after the
  /// analyzer reports it is no longer analyzing.
  final Duration idleDebounce;

  TaskStatusHandle? _initializationTask;
  TaskStatusHandle? _currentTask;
  Timer? _idleTimer;
  bool _initializationFinished = false;
  bool _unavailable = false;
  bool _disposed = false;

  /// Starts the task spanning analyzer startup and initial analysis.
  void beginInitialization() {
    if (_disposed || _initializationTask != null || _initializationFinished) {
      return;
    }
    _cancelIdleTimer();
    _initializationTask = _taskStatus.startTask(TaskKind.startingAnalyzer);
  }

  /// Applies an analyzer busy/idle notification.
  void update({required bool isAnalyzing}) {
    if (_disposed) {
      return;
    }
    if (isAnalyzing) {
      _cancelIdleTimer();
      _unavailable = false;
      if (_initializationTask != null) {
        return;
      }
      if (!_initializationFinished) {
        _initializationTask = _taskStatus.startTask(TaskKind.startingAnalyzer);
        return;
      }
      _currentTask ??= _taskStatus.startTask(TaskKind.analyzing);
      return;
    }

    if (_unavailable) {
      return;
    }

    if (_initializationTask case final task?) {
      task.succeed();
      _initializationTask = null;
      _initializationFinished = true;
    }

    if (_currentTask == null) {
      return;
    }

    if (idleDebounce == Duration.zero) {
      _currentTask?.succeed();
      _currentTask = null;
    } else {
      final finished = clock.now(); // see package:clock for easier testing
      _idleTimer?.cancel();
      _idleTimer = Timer(idleDebounce, () {
        _idleTimer = null;
        if (!_disposed) {
          _currentTask?.succeed(finishedAt: finished);
          _currentTask = null;
        }
      });
    }
  }

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Marks the analyzer as unavailable after startup or stream failure.
  void markUnavailable() {
    if (_disposed) {
      return;
    }
    _cancelIdleTimer();
    final hadActiveTask = _initializationTask != null || _currentTask != null;
    if (_initializationTask case final task?) {
      task.fail();
      _initializationTask = null;
    }
    if (_currentTask case final task?) {
      task.fail();
      _currentTask = null;
    }
    if (!hadActiveTask) {
      final kind = _initializationFinished ? TaskKind.analyzing : TaskKind.startingAnalyzer;
      _taskStatus.startTask(kind).fail();
    }
    _initializationFinished = true;
    _unavailable = true;
  }

  /// Resets the controller state and cancels any pending analysis tasks.
  void reset() {
    if (_disposed) {
      return;
    }
    _cancelIdleTimer();
    _initializationTask?.cancel();
    _initializationTask = null;
    _currentTask?.cancel();
    _currentTask = null;
    _initializationFinished = false;
    _unavailable = false;
  }

  /// Cancels any active tasks and disposes the controller.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _cancelIdleTimer();
    if (_initializationTask case final task?) {
      task.cancel();
      _initializationTask = null;
    }
    if (_currentTask case final task?) {
      task.cancel();
      _currentTask = null;
    }
  }
}
