// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/editor/components/error_toast.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/error_toast_event.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('shows an error toast and dismisses it after the configured duration', (tester) async {
    final events = AppEventBus();
    tester.pumpComponent(
      ErrorToast(
        events: events,
        displayDuration: const Duration(milliseconds: 500),
      ),
    );
    await pumpEventQueue();

    events.dispatch(const ErrorToastEvent('Saving failed, try again'));
    await pumpEventQueue();

    final toast = web.document.querySelector('.editor-error-toast');
    expect(toast, isNotNull);
    expect(toast!.textContent, contains('Saving failed, try again'));
    expect(toast.getAttribute('role'), 'alert');

    await Future<void>.delayed(const Duration(milliseconds: 550));
    await pumpEventQueue();

    expect(web.document.querySelector('.editor-error-toast'), isNull);
    await events.dispose();
  });
}
