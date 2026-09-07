// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/preview/view/preview_container.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/features/workspace/data/workspace_repository.dart';
import 'package:dartpad_frontend/features/workspace/workspace_session.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  group('PreviewContainer – collapse button', () {
    late AppEventBus events;
    late TaskStatusController taskStatus;
    late WorkspaceSession session;

    setUp(() {
      events = AppEventBus();
      taskStatus = TaskStatusController();
      session = WorkspaceSession.create(
        WorkspaceRepository.create(
          events: events,
          sdk: defaultSdk,
          taskStatus: taskStatus,
        ),
      );
    });

    tearDown(() async {
      await session.dispose(closeWorker: false);
      await events.dispose();
    });

    testClient('does not render collapse button when not in a SplitPanel', (tester) {
      tester.pumpComponent(
        PreviewContainer(
          preview: session.preview,
          taskStatus: taskStatus,
          activeFile: 'lib/main.dart',
          onOpenConsole: () {},
        ),
      );

      expect(web.document.querySelector('button[aria-label="Hide preview"]'), isNull);
    });

    testClient('renders collapse button when in SplitPanel', (tester) {
      tester.pumpComponent(
        SplitPanel(
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: session.preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      final button = web.document.querySelector('button[aria-label="Hide preview"]') as web.HTMLButtonElement?;
      expect(button, isNotNull);
      expect(button!.getAttribute('aria-label'), 'Hide preview');
    });

    testClient('renders preview-rail and keeps container mounted when collapsed in SplitPanel', (tester) {
      tester.pumpComponent(
        SplitPanel(
          initialState: const RightCollapsed(0.7),
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: session.preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);
      expect(web.document.querySelector('.preview-rail:not(.hidden)'), isNotNull);
      expect(web.document.querySelector('.preview-rail button'), isNotNull);
      expect(web.document.querySelector('.preview-toolbar.hidden'), isNotNull);
      expect(web.document.querySelector('.preview-content.collapsed'), isNotNull);
    });

    testClient('collapsing and expanding preserves containerElement in the DOM', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        SplitPanel(
          key: splitKey,
          initialState: const Split(0.7),
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: session.preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      final containerElement = session.preview.containerElement;
      expect(containerElement.isConnected, isTrue);

      // Collapse right panel
      splitKey.currentState!.collapseRight();
      await pumpEventQueue();

      expect(containerElement.isConnected, isTrue);
      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);

      // Expand right panel
      splitKey.currentState!.split();
      await pumpEventQueue();

      expect(containerElement.isConnected, isTrue);
      expect(web.document.querySelector('.preview-container:not(.collapsed)'), isNotNull);
    });
  });
}
