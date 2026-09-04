// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import 'task_status.dart';

/// The session-scoped lifecycle of the Dart analyzer.
enum AnalyzerStatusPhase { waiting, analyzing, ready, unavailable }

/// Tracks analyzer readiness separately from user-visible application tasks.
///
/// Analyzer startup and the first complete analysis are represented by one
/// normal task. Later analysis cycles only toggle [AnalyzerStatusPhase.analyzing]
/// and never replace or restart that initialization task.
final class AnalyzerStatusController extends ChangeNotifier {
  AnalyzerStatusController(this._taskStatus);

  final TaskStatusController _taskStatus;

  AnalyzerStatusPhase _phase = AnalyzerStatusPhase.waiting;
  TaskStatusHandle? _initializationTask;
  bool _initializationFinished = false;
  bool _disposed = false;

  AnalyzerStatusPhase get phase => _phase;

  /// Starts the single task spanning analyzer startup and initial analysis.
  void beginInitialization() {
    if (_disposed || _initializationTask != null || _initializationFinished) {
      return;
    }
    _initializationTask = _taskStatus.startTask(TaskKind.analyzingWorkspace);
    _setPhase(AnalyzerStatusPhase.analyzing);
  }

  /// Applies an analyzer busy/idle notification.
  void update({required bool isAnalyzing}) {
    if (_disposed) {
      return;
    }
    if (isAnalyzing) {
      _setPhase(AnalyzerStatusPhase.analyzing);
      return;
    }

    _initializationTask?.succeed();
    _initializationTask = null;
    _initializationFinished = true;
    _setPhase(AnalyzerStatusPhase.ready);
  }

  /// Marks the analyzer as unavailable after startup or stream failure.
  void markUnavailable() {
    if (_disposed) {
      return;
    }
    _initializationTask?.fail();
    _initializationTask = null;
    _initializationFinished = true;
    _setPhase(AnalyzerStatusPhase.unavailable);
  }

  void _setPhase(AnalyzerStatusPhase phase) {
    if (_phase == phase) {
      return;
    }
    _phase = phase;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _initializationTask?.cancel();
    _initializationTask = null;
    super.dispose();
  }
}
