// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartpad/dartpad.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

int get liveWorkers => (web.window['pendingWorkerCounts']['live'] as JSNumber).toDartInt;

void main() {
  const sdk = SdkInfo(
    id: 'pending-worker',
    name: 'Pending worker',
    path: '../../fixtures/pending_worker/',
    dartVersion: '3.12.0',
  );

  setUpAll(() {
    web.document.head!.appendChild(
      web.HTMLScriptElement()
        ..textContent = '''
          window.pendingWorkerCounts = {live: 0, workers: []};
          const NativeWorker = window.Worker;
          window.Worker = class extends NativeWorker {
            constructor(...args) {
              super(...args);
              this.retired = false;
              pendingWorkerCounts.live++;
              pendingWorkerCounts.workers.push(this);
            }
            terminate() {
              if (!this.retired) { this.retired = true; pendingWorkerCounts.live--; }
              super.terminate();
            }
          };
        ''',
    );
  });

  tearDown(() {
    // Also retire the blocked fixture when the regression assertion fails.
    (web.window['eval'] as JSFunction).callAsFunction(
      web.window,
      'pendingWorkerCounts.workers.forEach(worker => worker.terminate());'.toJS,
    );
  });

  test('suspending a pending worker terminates it before the session handshake', () async {
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository.create(events: events, taskStatus: tasks, sdk: sdk, deferWorker: true);
    addTearDown(repository.close);
    addTearDown(events.dispose);
    addTearDown(tasks.dispose);

    final started = repository.startWorker();
    started.ignore();
    expect(liveWorkers, 1);

    await repository.suspendWorker();

    expect(liveWorkers, 0);
    await expectLater(started, throwsA(isA<StateError>()));
    expect(repository.hasRuntime, isFalse);
  });

  test('a retired start cannot clear the resumed start cancellation handle', () async {
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository.create(events: events, taskStatus: tasks, sdk: sdk, deferWorker: true);
    addTearDown(repository.close);
    addTearDown(events.dispose);
    addTearDown(tasks.dispose);

    final first = repository.startWorker();
    first.ignore();
    final suspension = repository.suspendWorker();
    final resumed = repository.startWorker();
    resumed.ignore();
    // The Future trigger delivers cancellation asynchronously. Resume before
    // that delivery to exercise cleanup from the retired startup attempt.
    await suspension;
    await expectLater(first, throwsA(isA<StateError>()));
    expect(liveWorkers, 1);

    await repository.suspendWorker();
    expect(liveWorkers, 0);
    await expectLater(resumed, throwsA(isA<StateError>()));
  });

  test('closing a pending runtime terminates the worker and settles startup', () async {
    final events = AppEventBus();
    final tasks = TaskStatusController();
    final repository = WorkspaceRepository.create(events: events, taskStatus: tasks, sdk: sdk, deferWorker: true);
    addTearDown(events.dispose);
    addTearDown(tasks.dispose);
    addTearDown(repository.close);

    final started = repository.startWorker();
    started.ignore();
    expect(liveWorkers, 1);

    await repository.close();

    expect(liveWorkers, 0);
    await expectLater(started, throwsA(isA<StateError>()));
    expect(repository.isClosed, isTrue);
  });

  test('an already completed trigger aborts SDK startup', () async {
    final abort = Completer<void>()..complete();
    await expectLater(
      DartPadSdk(assetBaseUrl: sdk.assetBaseUrl).dedicatedWorker(abortTrigger: abort.future),
      throwsA(isA<StateError>()),
    );
    expect(liveWorkers, 0);
  });

  test('a native worker load failure settles startup and releases the worker', () async {
    await expectLater(
      DartPadSdk(
        assetBaseUrl: Uri.base.resolve('../../fixtures/missing_worker/'),
      ).dedicatedWorker().timeout(const Duration(seconds: 5)),
      throwsA(isA<StateError>()),
    );
    expect(liveWorkers, 0);
  });

  test('aborting after the handshake leaves ownership with the returned client', () async {
    final abort = Completer<void>();
    final client = await DartPadSdk(
      assetBaseUrl: Uri.base.resolve('../../fixtures/worker/'),
    ).dedicatedWorker(abortTrigger: abort.future);
    addTearDown(client.dispose);
    expect(liveWorkers, 1);

    abort.complete();
    await pumpEventQueue();
    expect(liveWorkers, 1);

    await client.dispose();
    expect(liveWorkers, 0);
  });
}
