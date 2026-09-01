// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/task_status_indicator.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late TaskStatusController controller;

  setUp(() {
    controller = TaskStatusController();
  });

  tearDown(() {
    controller.dispose();
  });

  testClient('shows workspace preparation tasks', (tester) async {
    tester.pumpComponent(
      PreviewTaskStatus(
        controller: controller,
        mode: PreviewTaskStatusMode.workspacePreparation,
        onOpenConsole: () {},
      ),
    );

    controller.startTask(TaskKind.analyzingWorkspace);
    controller.startTask(
      TaskKind.pubClean,
      label: 'Pub clean in /',
      scope: '/',
    );
    await pumpEventQueue();
    expect(_statusText, contains('Start the preview when you’re ready.'));

    final initializingWorker = controller.startTask(
      TaskKind.initializingDartPadWorker,
      blocksPreview: true,
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-status.running'), isNotNull);
    expect(_statusText, contains('Initializing DartPad worker'));
    expect(_statusText, isNot(contains('Pub clean')));

    initializingWorker.succeed();
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-status.idle'), isNotNull);
  });

  testClient('moves directly from compilation to preview startup', (tester) async {
    tester.pumpComponent(
      PreviewTaskStatus(
        controller: controller,
        mode: PreviewTaskStatusMode.startup,
        onOpenConsole: () {},
      ),
    );

    final starting = controller.startTask(TaskKind.startingPreview);
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-title')?.textContent, 'Starting preview');

    final compiling = controller.startTask(TaskKind.compilingApplication);
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-title')?.textContent, 'Compiling application');

    compiling.succeed();
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-title')?.textContent, 'Starting preview');

    starting.succeed();
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-status.idle'), isNotNull);
  });

  testClient('shows an explicit preview restart without showing stop tasks', (tester) async {
    tester.pumpComponent(
      PreviewTaskStatus(
        controller: controller,
        mode: PreviewTaskStatusMode.restart,
        onOpenConsole: () {},
      ),
    );

    controller.startTask(TaskKind.stoppingPreview);
    final restarting = controller.startTask(TaskKind.restartingPreview);
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-title')?.textContent, 'Restarting preview');
    expect(_statusText, isNot(contains('Stopping preview')));

    restarting.succeed();
    await pumpEventQueue();
    expect(web.document.querySelector('.preview-task-status.idle'), isNotNull);
  });

  testClient('keeps failures visible and opens the Console', (tester) async {
    var openConsoleCalls = 0;
    tester.pumpComponent(
      PreviewTaskStatus(
        controller: controller,
        mode: PreviewTaskStatusMode.workspacePreparation,
        persistentFailureMessage: 'Pub get failed.',
        onOpenConsole: () => openConsoleCalls++,
      ),
    );

    expect(web.document.querySelector('.preview-task-status.failed'), isNotNull);
    expect(_statusText, contains('Workspace preparation'));
    expect(_statusText, contains('Pub get failed.'));

    final link = web.document.querySelector('.preview-task-console-link')! as web.HTMLButtonElement;
    link.click();
    await pumpEventQueue();
    expect(openConsoleCalls, 1);
  });
}

String? get _statusText => web.document.querySelector('.preview-task-status')?.textContent;
