// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/analyzer_status.dart';
import 'package:dartpad_frontend/features/shared/components/footer.dart';
import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late TaskStatusController taskStatus;
  late AnalyzerStatusController analyzerStatus;

  setUp(() {
    taskStatus = TaskStatusController();
    analyzerStatus = AnalyzerStatusController(taskStatus);
  });

  tearDown(() {
    analyzerStatus.dispose();
    taskStatus.dispose();
  });

  testClient('renders desktop footer with privacy and feedback links', (tester) {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        analyzerStatus: analyzerStatus,
        isSmallScreen: false,
      ),
    );

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 2);

    final status = web.document.querySelector('.task-status-trigger');
    expect(status?.textContent, contains('Ready'));
  });

  testClient('renders small-screen footer without privacy and feedback links', (tester) {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        analyzerStatus: analyzerStatus,
        isSmallScreen: true,
      ),
    );

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 0);

    final status = web.document.querySelector('.task-status-trigger');
    expect(status?.textContent, contains('Ready'));
  });

  testClient('opens shortcuts dialog and toggles show more shortcuts', (tester) async {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        analyzerStatus: analyzerStatus,
        isSmallScreen: false,
      ),
    );

    // Initially dialog is not in the DOM.
    expect(web.document.querySelector('.shortcuts-dialog'), isNull);

    // Click keyboard shortcuts button.
    final keyboardBtn = web.document.querySelector('.app-footer-buttons button') as web.HTMLButtonElement?;
    expect(keyboardBtn, isNotNull);
    keyboardBtn?.click();
    await pumpEventQueue();

    final dialog = web.document.querySelector('.shortcuts-dialog');
    expect(dialog, isNotNull);

    // Verify primary shortcuts are present.
    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);

    // Toggle button is present.
    final toggleBtn = web.document.querySelector('.shortcuts-dialog-toggle-btn') as web.HTMLButtonElement?;
    expect(toggleBtn, isNotNull);
    expect(toggleBtn?.textContent, contains('Show more shortcuts'));

    // Expand show more.
    toggleBtn?.click();
    await pumpEventQueue();

    // All shortcut rows are visible.
    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, allShortcutCount);
    expect(toggleBtn?.textContent, contains('Show fewer shortcuts'));

    // Collapse show more.
    toggleBtn?.click();
    await pumpEventQueue();

    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);

    (web.document.querySelector('[aria-label="Close shortcuts dialog"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
  });

  testClient('task status update does not dismiss active shortcuts dialog', (tester) async {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        analyzerStatus: analyzerStatus,
        isSmallScreen: false,
      ),
    );

    // Open dialog.
    final keyboardBtn = web.document.querySelector('.app-footer-buttons button') as web.HTMLButtonElement?;
    keyboardBtn?.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);

    taskStatus.startTask(TaskKind.creatingWorkspace).succeed();
    await pumpEventQueue();

    // Dialog must still be open.
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);
    final status = web.document.querySelector('.task-status-trigger');
    expect(status?.textContent, contains('Creating workspace'));

    (web.document.querySelector('[aria-label="Close shortcuts dialog"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
  });

  testClient('shows active and completed tasks in the status popover', (tester) async {
    final completed = taskStatus.startTask(TaskKind.creatingWorkspace);
    completed.succeed();
    taskStatus.startTask(
      TaskKind.pubGet,
      label: 'Pub get in /',
      scope: '/',
    );
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        analyzerStatus: analyzerStatus,
        statusMessage: 'Could not save all files.',
      ),
    );

    final anchor = web.document.querySelector('.task-status-anchor')!;
    anchor.dispatchEvent(web.MouseEvent('mouseenter'));
    await pumpEventQueue();

    final rows = web.document.querySelectorAll('.task-status-table tr');
    expect(rows.length, 2);
    expect(rows.item(0)?.textContent, contains('Pub get in /'));
    expect(rows.item(1)?.textContent, contains('Creating workspace'));
    expect(web.document.querySelector('.app-footer-message')?.textContent, 'Could not save all files.');
  });

  testClient('shows a fixed analyzer label with activity, ready, and failure icons', (tester) async {
    tester.pumpComponent(
      Footer(taskStatus: taskStatus, analyzerStatus: analyzerStatus),
    );

    expect(web.document.querySelector('.analyzer-status.waiting'), isNotNull);
    expect(web.document.querySelector('.analyzer-status')?.textContent?.trim(), 'Analyzer');
    expect(web.document.querySelector('.analyzer-status .task-status-icon.running'), isNotNull);

    analyzerStatus.beginInitialization();
    analyzerStatus.update(isAnalyzing: true);
    await pumpEventQueue();
    expect(web.document.querySelector('.analyzer-status.analyzing'), isNotNull);
    expect(web.document.querySelector('.analyzer-status')?.textContent?.trim(), 'Analyzer');
    expect(web.document.querySelector('.analyzer-status-duration'), isNull);

    analyzerStatus.update(isAnalyzing: false);
    await pumpEventQueue();
    expect(web.document.querySelector('.analyzer-status.ready'), isNotNull);
    expect(web.document.querySelector('.analyzer-status .task-status-icon.succeeded'), isNotNull);

    analyzerStatus.update(isAnalyzing: true);
    await pumpEventQueue();
    expect(web.document.querySelector('.analyzer-status.analyzing'), isNotNull);
    expect(web.document.querySelector('.analyzer-status')?.textContent?.trim(), 'Analyzer');
    expect(taskStatus.entries, hasLength(1));

    analyzerStatus.markUnavailable();
    await pumpEventQueue();
    expect(web.document.querySelector('.analyzer-status.unavailable'), isNotNull);
    expect(web.document.querySelector('.analyzer-status .task-status-icon.failed'), isNotNull);
  });

  testClient('opens by focus or click and closes with Escape', (tester) async {
    taskStatus.startTask(TaskKind.analyzingWorkspace);
    tester.pumpComponent(
      Footer(taskStatus: taskStatus, analyzerStatus: analyzerStatus),
    );

    final trigger = web.document.querySelector('.task-status-trigger') as web.HTMLButtonElement;
    trigger.focus();
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNotNull);

    web.document.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNull);

    trigger.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNotNull);
  });
}
