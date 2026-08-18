// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:test/test.dart';

void main() {
  test('dispatchAsync completes with the event result', () async {
    final events = AppEventBus();
    final subscription = events.on<_TestEvent>().listen((event) {
      event.complete('done');
    });

    await expectLater(events.dispatchAsync(_TestEvent()), completion('done'));

    await subscription.cancel();
    await events.dispose();
  });

  test('dispatchAsync completes void events without a value', () async {
    final events = AppEventBus();
    final subscription = events.on<_TestVoidEvent>().listen((event) {
      event.complete();
    });

    await expectLater(events.dispatchAsync(_TestVoidEvent()), completes);

    await subscription.cancel();
    await events.dispose();
  });

  test('events remain strongly typed', () async {
    final events = AppEventBus();
    final typedEvents = events.on<_TypedEvent>().toList();

    events.dispatch(_TestVoidEvent());
    events.dispatch(const _TypedEvent());
    await events.dispose();

    expect(await typedEvents, hasLength(1));
  });

  test('late events are ignored after dispose', () async {
    final events = AppEventBus();

    await events.dispose();
    events.dispatch(const _TypedEvent());
    await events.dispose();
  });

  test('late async events complete with an error after dispose', () async {
    final events = AppEventBus();
    await events.dispose();

    await expectLater(
      events.dispatchAsync(_TestEvent()),
      throwsA(isA<StateError>()),
    );
  });
}

final class _TypedEvent extends AppEvent {
  const _TypedEvent();
}

final class _TestEvent extends AsyncEvent<String> {}

final class _TestVoidEvent extends VoidAsyncEvent {}
