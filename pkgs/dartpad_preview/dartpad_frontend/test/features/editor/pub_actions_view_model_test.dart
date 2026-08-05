// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/editor/view_models/pub_actions_view_model.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  late AppEventBus events;
  late List<LogEvent> logs;
  late StreamSubscription<LogEvent> logSubscription;
  late List<String> operations;
  late Future<void> Function() saveAllFiles;
  late Future<void> Function(String path) pubGetAction;
  late Future<void> Function(String path) pubCleanAction;
  late PubActionsViewModel viewModel;

  setUp(() {
    events = AppEventBus();
    logs = [];
    logSubscription = events.on<LogEvent>().listen(logs.add);
    operations = [];
    saveAllFiles = () async => operations.add('save-all');
    pubGetAction = (path) async => operations.add('pub-get:$path');
    pubCleanAction = (path) async => operations.add('pub-clean:$path');
    viewModel = PubActionsViewModel(
      saveAllFiles: () => saveAllFiles(),
      events: events,
      pubGetAction: (path) => pubGetAction(path),
      pubCleanAction: (path) => pubCleanAction(path),
    );
  });

  tearDown(() async {
    viewModel.dispose();
    await logSubscription.cancel();
    await events.dispose();
  });

  test('saves all files before running Pub Get in the requested path', () async {
    await viewModel.pubGet('packages/example');

    expect(operations, ['save-all', 'pub-get:packages/example']);
    expect(viewModel.busy, isFalse);
  });

  test('runs Pub Clean without saving files', () async {
    await viewModel.pubClean('packages/example');

    expect(operations, ['pub-clean:packages/example']);
  });

  test('logs failures and resets busy state', () async {
    pubGetAction = (_) async => throw StateError('pub failed');

    await viewModel.pubGet('packages/example');
    await pumpEventQueue();

    expect(operations, ['save-all']);
    expect(viewModel.busy, isFalse);
    expect(logs.single.level, Level.SEVERE);
    expect(logs.single.message, 'Pub get failed.');
    expect(logs.single.error, isA<StateError>());
  });

  test('stops after a save failure without reporting a Pub failure', () async {
    saveAllFiles = () async {
      operations.add('save-all');
      throw StateError('save failed');
    };

    await viewModel.pubGet('packages/example');
    await pumpEventQueue();

    expect(operations, ['save-all']);
    expect(logs, isEmpty);
    expect(viewModel.busy, isFalse);
  });

  test('ignores another Pub action while one is running', () async {
    final completer = Completer<void>();
    pubGetAction = (path) async {
      operations.add('pub-get:$path');
      await completer.future;
    };

    final firstRun = viewModel.pubGet('packages/first');
    await pumpEventQueue();
    await viewModel.pubClean('packages/second');

    expect(viewModel.busy, isTrue);
    expect(operations, ['save-all', 'pub-get:packages/first']);

    completer.complete();
    await firstRun;
    expect(viewModel.busy, isFalse);
  });
}
