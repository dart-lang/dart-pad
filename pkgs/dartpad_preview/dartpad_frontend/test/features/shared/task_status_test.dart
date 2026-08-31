// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:test/test.dart';

void main() {
  group('TaskStatusController', () {
    late DateTime now;
    late TaskStatusController controller;

    setUp(() {
      now = DateTime.utc(2026, 8, 28, 12);
      controller = TaskStatusController(now: () => now);
    });

    tearDown(() {
      controller.dispose();
    });

    test('orders running tasks before completed tasks', () {
      final first = controller.startTask(
        TaskKind.loadingSample,
        label: 'First',
        scope: 'first',
      );
      now = now.add(const Duration(seconds: 1));
      final second = controller.startTask(
        TaskKind.pubGet,
        label: 'Second',
        scope: '/',
      );
      first.succeed();

      expect(controller.entries.map((entry) => entry.label), ['Second', 'First']);
      expect(controller.current?.label, 'Second');

      now = now.add(const Duration(seconds: 1));
      second.succeed();
      expect(controller.entries.map((entry) => entry.label), ['Second', 'First']);
    });

    test('replaces the same kind and scope and ignores its stale handle', () {
      final stale = controller.startTask(
        TaskKind.pubGet,
        label: 'First pub get',
        scope: '/example',
      );
      now = now.add(const Duration(seconds: 1));
      final current = controller.startTask(
        TaskKind.pubGet,
        label: 'Current pub get',
        scope: '/example',
      );

      stale.fail();
      expect(controller.entries, hasLength(1));
      expect(controller.current?.label, 'Current pub get');
      expect(controller.current?.outcome, TaskStatusOutcome.running);

      current.succeed();
      expect(controller.current?.outcome, TaskStatusOutcome.succeeded);
    });

    test('keeps the same kind with different scopes independently', () {
      controller.startTask(
        TaskKind.pubGet,
        label: 'Pub get in /first',
        scope: '/first',
      );
      controller.startTask(
        TaskKind.pubGet,
        label: 'Pub get in /second',
        scope: '/second',
      );

      expect(controller.entries, hasLength(2));
      expect(
        controller.entries.map((entry) => entry.scope),
        unorderedEquals(['/first', '/second']),
      );
      expect(controller.entries.every((entry) => entry.kind == TaskKind.pubGet), isTrue);
    });

    test('runTask records success and preserves the result', () async {
      final result = await controller.runTask(
        TaskKind.loadingSample,
        () async => 42,
        label: 'Load sample counter',
        scope: 'counter',
      );

      expect(result, 42);
      expect(controller.current?.label, 'Load sample counter');
      expect(controller.current?.outcome, TaskStatusOutcome.succeeded);
    });

    test('runTask records and rethrows synchronous and asynchronous errors', () async {
      expect(
        () => controller.runTask<void>(
          TaskKind.loadingSample,
          () => throw StateError('sync'),
          scope: 'sync',
        ),
        throwsStateError,
      );
      await pumpEventQueue();
      expect(controller.current?.outcome, TaskStatusOutcome.failed);

      now = now.add(const Duration(seconds: 1));
      await expectLater(
        controller.runTask<void>(
          TaskKind.loadingSample,
          () async => throw StateError('async'),
          label: 'Async failure',
          scope: 'async',
        ),
        throwsStateError,
      );
      expect(controller.current?.label, 'Async failure');
      expect(controller.current?.outcome, TaskStatusOutcome.failed);
    });

    test('tracks whether a running task blocks preview compilation', () {
      final passive = controller.startTask(TaskKind.analyzingWorkspace);
      expect(controller.hasBlockingPreviewTask, isFalse);

      final blocking = controller.startTask(
        TaskKind.pubGet,
        scope: '/',
        blocksPreview: true,
      );
      expect(controller.hasBlockingPreviewTask, isTrue);

      blocking.succeed();
      expect(controller.hasBlockingPreviewTask, isFalse);
      passive.cancel();
    });

    test('removes completed tasks after retention but keeps running tasks', () {
      controller.startTask(TaskKind.loadingSample, scope: 'completed').succeed();
      controller.startTask(TaskKind.analyzingWorkspace);

      now = now.add(const Duration(minutes: 5, milliseconds: 1));
      controller.startTask(TaskKind.pubClean, scope: '/').cancel();

      expect(controller.entries.map((entry) => entry.kind), [TaskKind.analyzingWorkspace]);
    });

    test('cancel removes only the handle-owned task', () {
      final handle = controller.startTask(TaskKind.hotReload);
      handle.cancel();

      expect(controller.entries, isEmpty);
    });

    test('dispose clears tasks and makes existing handles inert', () {
      final handle = controller.startTask(TaskKind.analyzingWorkspace);

      controller.dispose();
      handle.succeed();

      expect(controller.entries, isEmpty);
      expect(
        () => controller.startTask(TaskKind.pubGet),
        throwsStateError,
      );

      controller = TaskStatusController(now: () => now);
    });
  });

  group('formatTaskDuration', () {
    test('formats tenths of seconds, minutes, and hours', () {
      expect(formatTaskDuration(const Duration(milliseconds: 950)), '0.9s');
      expect(formatTaskDuration(const Duration(seconds: 61)), '1m 01s');
      expect(formatTaskDuration(const Duration(hours: 1, minutes: 2, seconds: 3)), '1h 02m 03s');
    });

    test('clamps negative durations', () {
      expect(formatTaskDuration(const Duration(milliseconds: -1)), '0.0s');
    });
  });
}
