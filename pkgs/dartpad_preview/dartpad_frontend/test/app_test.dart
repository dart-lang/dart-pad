// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/app.dart';
import 'package:test/test.dart';
import 'package:web/web.dart' as web;

void main() {
  test('handleBeforeUnload prevents default', () {
    final event =
        web.Event(
              'beforeunload',
              web.EventInit(cancelable: true),
            )
            as web.BeforeUnloadEvent;

    expect(event.defaultPrevented, isFalse);

    handleBeforeUnload(event);

    expect(event.defaultPrevented, isTrue);
  });

  test('beforeunload listener on window invokes handleBeforeUnload', () async {
    final completer = Completer<web.BeforeUnloadEvent>();
    final subscription = web.EventStreamProviders.beforeUnloadEvent.forTarget(web.window).listen((event) {
      handleBeforeUnload(event);
      completer.complete(event);
    });
    addTearDown(subscription.cancel);

    final event = web.Event(
      'beforeunload',
      web.EventInit(cancelable: true),
    );
    web.window.dispatchEvent(event);

    final handledEvent = await completer.future;
    expect(handledEvent.defaultPrevented, isTrue);
  });
}
