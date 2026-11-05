// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:dartpad_frontend/features/shared/workspace_mode.dart';
import 'package:dartpad_frontend/features/workspace/workspace_layout.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  for (final showOutput in [false, true]) {
    testClient('mobile preview follows split updates without an ancestor rebuild: showOutput=$showOutput', (
      tester,
    ) async {
      final panels = PanelLayoutController(mode: WorkspaceMode.standalone, isSmallScreen: true);
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        panels.dispose();
      });
      tester.pumpComponent(
        WorkspaceLayout(
          fileTree: const div([]),
          editor: const div(id: 'editor', []),
          preview: const div(id: 'preview', []),
          panels: panels,
          showOutput: showOutput,
        ),
      );
      final split =
          (find.byType(SplitPanel).evaluate().singleWhere((element) => (element.component as SplitPanel).useRatio)
                      as StatefulElement)
                  .state
              as SplitPanelState;
      final editor = web.document.getElementById('editor')! as web.HTMLElement;
      final preview = web.document.getElementById('preview')! as web.HTMLElement;

      for (final state in [const Split(0.65), const RightCollapsed(0.8), const RightHidden(0.4)]) {
        panels.updatePreview(state);
        await pumpEventQueue();
        expect(split.state, showOutput ? LeftHidden(state.value) : RightHidden(state.value));
        expect(editor.style.display, showOutput ? 'none' : '');
        expect(preview.style.display, showOutput ? '' : 'none');
        expect(panels.preview, state);
      }

      // Expansion requests must use the latest ratio, even while a tab hides a pane.
      split.split();
      await pumpEventQueue();
      expect(panels.preview, const Split(0.4));
      expect(split.state, showOutput ? const LeftHidden(0.4) : const RightHidden(0.4));

      panels.updateScreenSize(isSmallScreen: false);
      await pumpEventQueue();
      expect(split.state, const Split(0.4));
      expect(editor.style.display, '');
      expect(preview.style.display, '');
      expect(editor.style.flexGrow, '0.4');
      expect(preview.style.flexGrow, '0.6');
      expect(web.document.getElementById('editor')!.isSameNode(editor), isTrue);
      expect(web.document.getElementById('preview')!.isSameNode(preview), isTrue);
    });
  }
}
