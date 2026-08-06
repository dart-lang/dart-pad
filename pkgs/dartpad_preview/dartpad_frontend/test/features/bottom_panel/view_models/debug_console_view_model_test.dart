// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:dartpad_frontend/features/bottom_panel/view_models/debug_console_view_model.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/events/log_event.dart';
import 'package:logging/logging.dart';
import 'package:test/test.dart';

void main() {
  group('DebugConsoleViewModel', () {
    late AppEventBus events;
    late DebugConsoleViewModel viewModel;

    setUp(() {
      events = AppEventBus();
      viewModel = DebugConsoleViewModel(events: events);
    });

    tearDown(() async {
      viewModel.dispose();
      await events.dispose();
    });

    test('captures multi-line messages, errors, and stack traces', () async {
      events.dispatch(
        LogEvent(
          'Resolving dependencies...\n  dependency resolved\n\nnext step\n',
          level: Level.SEVERE,
          error: StateError('failed'),
          stackTrace: StackTrace.fromString('trace one\ntrace two\n'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        viewModel.logs.map((entry) => entry.message),
        [
          'Resolving dependencies...',
          '  dependency resolved',
          '',
          'next step',
          'Bad state: failed',
          'trace one',
          'trace two',
        ],
      );
      expect(viewModel.logs.every((entry) => entry.level == Level.SEVERE), isTrue);
    });

    test('clears logs and notifies listeners', () async {
      var notifications = 0;
      viewModel.addListener(() => notifications++);

      events.dispatch(const LogEvent('Running pub get in /'));
      await Future<void>.delayed(Duration.zero);
      viewModel.clear();

      expect(viewModel.logs, isEmpty);
      expect(notifications, 2);
    });
  });
}
