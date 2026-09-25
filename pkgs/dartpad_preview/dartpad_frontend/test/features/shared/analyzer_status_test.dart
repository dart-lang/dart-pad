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
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: Duration.zero,
      );

      controller.beginInitialization();
      controller.beginInitialization();
      expect(taskStatus.entries, hasLength(1));
      expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
      expect(taskStatus.current?.label, 'Starting analyzer');
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);
      expect(taskStatus.hasBlockingPreviewTask, isFalse);

      now = now.add(const Duration(seconds: 3));
      controller.update(isAnalyzing: true);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      controller.update(isAnalyzing: false);
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
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: Duration.zero,
      );

      controller.beginInitialization();
      now = now.add(const Duration(seconds: 2));
      controller.update(isAnalyzing: false);
      final initialTask = taskStatus.current!;
      expect(initialTask.kind, TaskKind.startingAnalyzer);

      now = now.add(const Duration(minutes: 1));
      controller.update(isAnalyzing: true);
      expect(taskStatus.entries, hasLength(2));
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.label, 'Analyzing');
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      now = now.add(const Duration(seconds: 1));
      controller.update(isAnalyzing: false);
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
    final controller = AnalyzerStatusController(
      taskStatus,
      idleDebounce: Duration.zero,
    );

    controller.beginInitialization();
    controller.markUnavailable();
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);

    controller.update(isAnalyzing: true);
    expect(taskStatus.current?.kind, TaskKind.analyzing);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.update(isAnalyzing: false);
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
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: Duration.zero,
      );
      controller.beginInitialization();
      now = now.add(const Duration(seconds: 1));
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);

      now = now.add(const Duration(seconds: 1));
      controller.markUnavailable();
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

      // Trailing isAnalyzing: false updates must not create or succeed tasks.
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

      controller.dispose();
      taskStatus.dispose();
    });
  });

  test('markUnavailable before beginInitialization records a failed startingAnalyzer task', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);

    controller.markUnavailable();
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

    controller.update(isAnalyzing: false);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

    controller.dispose();
    taskStatus.dispose();
  });

  test('reset cancels active tasks and clears initialization state', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(taskStatus);

    controller.beginInitialization();
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.reset();
    expect(taskStatus.entries, isEmpty);

    // After reset, initialization can begin anew.
    controller.beginInitialization();
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.dispose();
    taskStatus.dispose();
  });

  test('reset after markUnavailable clears unavailable state', () {
    final taskStatus = TaskStatusController();
    final controller = AnalyzerStatusController(
      taskStatus,
      idleDebounce: Duration.zero,
    );

    controller.markUnavailable();
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

    controller.reset();

    // After reset, initialization begins with a fresh startingAnalyzer task.
    controller.beginInitialization();
    expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

    controller.update(isAnalyzing: false);
    expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);

    controller.dispose();
    taskStatus.dispose();
  });

  group('idle debouncing', () {
    test('records the idle time instead of the debounce deadline', () async {
      var now = DateTime.utc(2026, 8, 31, 12);
      await withClock(Clock(() => now), () async {
        final taskStatus = TaskStatusController();
        final controller = AnalyzerStatusController(
          taskStatus,
          idleDebounce: const Duration(milliseconds: 20),
        );

        controller.beginInitialization();
        controller.update(isAnalyzing: false);
        controller.update(isAnalyzing: true);
        now = now.add(const Duration(milliseconds: 5));
        controller.update(isAnalyzing: false);

        expect(taskStatus.current?.outcome, TaskStatusOutcome.running);
        now = now.add(const Duration(milliseconds: 250));
        await Future<void>.delayed(const Duration(milliseconds: 30));

        final analysis = taskStatus.entries.firstWhere((e) => e.kind == TaskKind.analyzing);
        expect(analysis.outcome, TaskStatusOutcome.succeeded);
        expect(analysis.finishedAt, DateTime.utc(2026, 8, 31, 12, 0, 0, 5));
        expect(analysis.durationAt(now), const Duration(milliseconds: 5));

        controller.dispose();
        taskStatus.dispose();
      });
    });

    test('debounces idle transitions during rapid analyzer bursts', () async {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: const Duration(milliseconds: 50),
      );

      controller.beginInitialization();
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.kind, TaskKind.startingAnalyzer);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);

      // Simulate rapid reference search burst across multiple files:
      // true -> false -> true -> false -> true -> false
      controller.update(isAnalyzing: true);
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // First file finishes indexing:
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: false);
      // Remains running (does not flicker to succeeded or disappear)!
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Second file requested:
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: true);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Second file finishes indexing:
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Third file requested:
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: true);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Third file finishes:
      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Now wait until idle timer runs to completion without new requests:
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(taskStatus.current?.outcome, TaskStatusOutcome.succeeded);

      // Exactly one analyzing task was created, not three!
      final analyzingEntries = taskStatus.entries.where((e) => e.kind == TaskKind.analyzing).toList();
      expect(analyzingEntries, hasLength(1));

      controller.dispose();
      taskStatus.dispose();
    });

    test('markUnavailable immediately fails an active task during debounce', () async {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: const Duration(milliseconds: 50),
      );

      controller.beginInitialization();
      controller.update(isAnalyzing: false);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: true);
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      // Mark unavailable during the debounce period:
      controller.markUnavailable();
      final analyzingEntry = taskStatus.entries.firstWhere((e) => e.kind == TaskKind.analyzing);
      expect(analyzingEntry.outcome, TaskStatusOutcome.failed);

      // Advancing past debounce duration does not resurrect or succeed the task
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(analyzingEntry.outcome, TaskStatusOutcome.failed);

      controller.dispose();
      taskStatus.dispose();
    });

    test('reset cancels an active task during debounce', () async {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: const Duration(milliseconds: 50),
      );

      controller.beginInitialization();
      controller.update(isAnalyzing: false);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: true);
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      controller.reset();
      expect(taskStatus.entries.where((e) => e.kind == TaskKind.analyzing), isEmpty);

      // Advancing past debounce does not execute
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(taskStatus.entries.where((e) => e.kind == TaskKind.analyzing), isEmpty);

      controller.dispose();
      taskStatus.dispose();
    });

    test('dispose cancels an active task and idle timer', () async {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(
        taskStatus,
        idleDebounce: const Duration(milliseconds: 50),
      );

      controller.beginInitialization();
      controller.update(isAnalyzing: false);

      await Future<void>.delayed(const Duration(milliseconds: 10));
      controller.update(isAnalyzing: true);
      controller.update(isAnalyzing: false);
      expect(taskStatus.current?.kind, TaskKind.analyzing);
      expect(taskStatus.current?.outcome, TaskStatusOutcome.running);

      controller.dispose();
      expect(taskStatus.entries.where((e) => e.kind == TaskKind.analyzing), isEmpty);

      // Advancing past debounce does not throw or mutate
      await Future<void>.delayed(const Duration(milliseconds: 60));
      taskStatus.dispose();
    });
  });
}
