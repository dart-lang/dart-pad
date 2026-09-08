// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/editor/components/pubspec_editor_actions.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:logging/logging.dart';
import 'package:web/web.dart' as web;

void main() {
  late AppEventBus events;

  setUp(() {
    events = AppEventBus();
  });

  tearDown(() async {
    await events.dispose();
  });

  testClient('runs root pubspec action in the workspace root', (tester) async {
    String? pubGetPath;
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (path) async => pubGetPath = path,
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(pubGetPath, '');
  });

  testClient('uses the directory of a nested pubspec lock', (tester) async {
    String? pubGetPath;
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'packages/example/pubspec.lock',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (path) async => pubGetPath = path,
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(pubGetPath, 'packages/example');
  });

  testClient('does not render actions for other active files', (tester) {
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'packages/example/analysis_options.yaml',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (_) async {},
      ),
    );

    expect(web.document.querySelector('.pubspec-editor-actions'), isNull);
  });

  testClient('renders actions after switching from another active file', (tester) async {
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'main.dart',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (_) async {},
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.pubspec-editor-actions'), isNull);

    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (_) async {},
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('[aria-label="Pub get"]'), isNotNull);
  });

  testClient('saves all files before running Pub Get', (tester) async {
    final operations = <String>[];
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async => operations.add('save-all'),
        events: events,
        onPubGet: (path) async => operations.add('pub-get:$path'),
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(operations, ['save-all', 'pub-get:']);
  });

  testClient('logs failures and resets busy state', (tester) async {
    final logs = <LogEvent>[];
    final logSubscription = events.on<LogEvent>().listen(logs.add);
    addTearDown(logSubscription.cancel);

    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (_) async => throw StateError('pub failed'),
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(logs.single.level, Level.SEVERE);
    expect(logs.single.message, 'Pub get failed.');
    expect(logs.single.error, isA<StateError>());

    final pubGet = web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement;
    expect(pubGet.disabled, isFalse);
  });

  testClient('stops after save failure without reporting a Pub failure', (tester) async {
    final logs = <LogEvent>[];
    final logSubscription = events.on<LogEvent>().listen(logs.add);
    addTearDown(logSubscription.cancel);

    final operations = <String>[];
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async {
          operations.add('save-all');
          throw StateError('save failed');
        },
        events: events,
        onPubGet: (path) async => operations.add('pub-get:$path'),
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    expect(operations, ['save-all']);
    expect(logs, isEmpty);

    final pubGet = web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement;
    expect(pubGet.disabled, isFalse);
  });

  testClient('disables action while busy', (tester) async {
    final completer = Completer<void>();
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async {},
        events: events,
        onPubGet: (_) => completer.future,
      ),
    );

    (web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement).click();
    await pumpEventQueue();

    final pubGet = web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement;
    expect(pubGet.disabled, isTrue);

    completer.complete();
    await pumpEventQueue();

    expect(pubGet.disabled, isFalse);
  });

  testClient('ignores another Pub action while one is running', (tester) async {
    final completer = Completer<void>();
    final operations = <String>[];
    tester.pumpComponent(
      PubspecEditorActions(
        activeFile: 'pubspec.yaml',
        saveAllFiles: () async => operations.add('save-all'),
        events: events,
        onPubGet: (path) async {
          operations.add('pub-get:$path');
          await completer.future;
        },
      ),
    );

    final pubGet = web.document.querySelector('[aria-label="Pub get"]')! as web.HTMLButtonElement;
    pubGet.click();
    await pumpEventQueue();
    pubGet.click();
    await pumpEventQueue();

    expect(operations, ['save-all', 'pub-get:']);

    completer.complete();
    await pumpEventQueue();
  });
}
