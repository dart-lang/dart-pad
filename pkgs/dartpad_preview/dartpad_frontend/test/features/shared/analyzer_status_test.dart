// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:clock/clock.dart';
import 'package:dartpad_frontend/features/shared/analyzer_status.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:test/test.dart';

void main() {
  test('tracks startup and initial analysis as one task', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    withClock(Clock(() => now), () {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(taskStatus);

      controller.beginInitialization();
      controller.beginInitialization();
      expect(controller.phase, AnalyzerStatusPhase.analyzing);
      expect(taskStatus.entries, hasLength(1));
      expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
      expect(taskStatus.current?.label, 'Starting analyzer');
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);
      expect(taskStatus.hasBlockingPreviewTask, isFalse);

      now = now.add(const Duration(seconds: 3));
      controller.update(isAnalyzing: true);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      controller.update(isAnalyzing: false);
      expect(controller.phase, AnalyzerStatusPhase.ready);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);
      expect(taskStatus.current?.durationAt(now), const Duration(seconds: 3));

      controller.dispose();
      taskStatus.dispose();
    });
  });

  test('later analysis cycles track an analyzing task and replace earlier runs', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    withClock(Clock(() => now), () {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(taskStatus);

      controller.beginInitialization();
      now = now.add(const Duration(seconds: 2));
      controller.update(isAnalyzing: false);
      final initialTask = taskStatus.current!;
      expect(initialTask.kind, TaskKind.startingAnalyzer);

      now = now.add(const Duration(minutes: 1));
      controller.update(isAnalyzing: true);
      expect(controller.phase, AnalyzerStatusPhase.analyzing);
      expect(taskStatus.entries, hasLength(2));
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.label, 'Analyzing');
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      now = now.add(const Duration(seconds: 1));
      controller.update(isAnalyzing: false);
      expect(controller.phase, AnalyzerStatusPhase.ready);
      expect(taskStatus.entries, hasLength(2));
      final firstCycle = taskStatus.entries.firstWhere((e) => e.kind == TaskKind.analyzing);
      expect(firstCycle.outcome, TaskStatusOutcome.succeeded);
      expect(firstCycle.durationAt(now), const Duration(seconds: 1));

      // Starting another analysis cycle replaces the previous analyzing entry.
      now = now.add(const Duration(minutes: 1));
      controller.update(isAnalyzing: true);
      expect(taskStatus.entries, hasLength(2));
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);
      expect(taskStatus.entries, contains(initialTask));

      now = now.add(const Duration(seconds: 2));
      controller.update(isAnalyzing: false);
      expect(taskStatus.entries, hasLength(2));
      final secondCycle = taskStatus.entries.firstWhere((e) => e.kind == TaskKind.analyzing);
      expect(secondCycle.outcome, TaskStatusOutcome.succeeded);
      expect(secondCycle.durationAt(now), const Duration(seconds: 2));

      controller.dispose();
      taskStatus.dispose();
    });
  });

  test('fails the pending task and can later recover its activity state', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);

    controller.beginInitialization();
    controller.markUnavailable();
    expect(controller.phase, AnalyzerStatusPhase.unavailable);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);

    controller.update(isAnalyzing: true);
    expect(controller.phase, AnalyzerStatusPhase.analyzing);
    expect(taskStatus.current?.kind, TaskKind.analyzing);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.update(isAnalyzing: false);
    expect(controller.phase, AnalyzerStatusPhase.ready);
    expect(taskStatus.entries, hasLength(2));
    expect(taskStatus.entries.firstWhere((e) => e.kind == TaskKind.analyzing).outcome, TaskStatusOutcome.succeeded);
    expect(taskStatus.entries.firstWhere((e) => e.kind == TaskKind.startingAnalyzer).outcome, TaskStatusOutcome.failed);

    controller.dispose();
    taskStatus.dispose();
  });

  test('dispose cancels a pending initialization task', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);
    controller.beginInitialization();

    controller.dispose();

    expect(taskStatus.entries, isEmpty);
    taskStatus.dispose();
  });

  test('dispose cancels a pending analyzing task', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);
    controller.beginInitialization();
    controller.update(isAnalyzing: false);
    controller.update(isAnalyzing: true);
    expect(taskStatus.current?.kind, TaskKind.analyzing);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.dispose();

    expect(taskStatus.entries.where((e) => e.kind == TaskKind.analyzing), isEmpty);
    taskStatus.dispose();
  });

  test('markUnavailable while idle records a failed analyzing task', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    withClock(Clock(() => now), () {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(taskStatus);
      controller.beginInitialization();
      now = now.add(const Duration(seconds: 1));
      controller.update(isAnalyzing: false);
      expect(controller.phase, AnalyzerStatusPhase.ready);
      expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);

      now = now.add(const Duration(seconds: 1));
      controller.markUnavailable();
      expect(controller.phase, AnalyzerStatusPhase.unavailable);
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

      // Trailing isAnalyzing: false updates must not revert phase to ready.
      controller.update(isAnalyzing: false);
      expect(controller.phase, AnalyzerStatusPhase.unavailable);

      controller.dispose();
      taskStatus.dispose();
    });
  });

  test('markUnavailable before beginInitialization records a failed startingAnalyzer task', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);

    controller.markUnavailable();
    expect(controller.phase, AnalyzerStatusPhase.unavailable);
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

    controller.update(isAnalyzing: false);
    expect(controller.phase, AnalyzerStatusPhase.unavailable);

    controller.dispose();
    taskStatus.dispose();
  });
}
