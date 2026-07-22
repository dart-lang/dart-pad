// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_preview/features/shared/app_event_bus.dart';
import 'package:test/test.dart';

void main() {
  test('dispatchAsync completes with the command result', () async {
    final events = AppEventBus();
    final subscription = events.on<_TestCommand>().listen((command) {
      command.complete('done');
    });

    await expectLater(events.dispatchAsync(_TestCommand()), completion('done'));

    await subscription.cancel();
    await events.dispose();
  });

  test('dispatchAsync completes void commands without a value', () async {
    final events = AppEventBus();
    final subscription = events.on<_TestVoidCommand>().listen((command) {
      command.complete();
    });

    await expectLater(events.dispatchAsync(_TestVoidCommand()), completes);

    await subscription.cancel();
    await events.dispose();
  });

  test('events remain strongly typed', () async {
    final events = AppEventBus();
    final logs = events.on<LogEvent>().toList();

    events.dispatch(_TestVoidCommand());
    events.dispatch(const LogEvent('ready'));
    await events.dispose();

    expect(await logs, hasLength(1));
  });
}

final class _TestCommand extends AsyncCommand<String> {}

final class _TestVoidCommand extends VoidAsyncCommand {}
