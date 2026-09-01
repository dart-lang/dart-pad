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
      expect(taskStatus.current?.kind, TaskKind.analyzingWorkspace);
      expect(taskStatus.current?.label, 'Analyzing workspace');
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

  test('later analysis cycles do not replace or restart the initial task', () {
    var now = DateTime.utc(2026, 8, 31, 12);
    withClock(Clock(() => now), () {
      final taskStatus = TaskStatusController();
      final controller = AnalyzerStatusController(taskStatus);

      controller.beginInitialization();
      now = now.add(const Duration(seconds: 2));
      controller.update(isAnalyzing: false);
      final initialTask = taskStatus.current!;

      now = now.add(const Duration(minutes: 1));
      controller.update(isAnalyzing: true);
      expect(controller.phase, AnalyzerStatusPhase.analyzing);
      expect(taskStatus.entries, [same(initialTask)]);

      now = now.add(const Duration(seconds: 1));
      controller.update(isAnalyzing: false);
      expect(controller.phase, AnalyzerStatusPhase.ready);
      expect(taskStatus.entries, [same(initialTask)]);
      expect(initialTask.durationAt(now), const Duration(seconds: 2));

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

    controller.update(isAnalyzing: true);
    expect(controller.phase, AnalyzerStatusPhase.analyzing);
    controller.update(isAnalyzing: false);
    expect(controller.phase, AnalyzerStatusPhase.ready);
    expect(taskStatus.entries, hasLength(1));
    expect(taskStatus.current?.outcome, TaskStatusOutcome.failed);

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
}
