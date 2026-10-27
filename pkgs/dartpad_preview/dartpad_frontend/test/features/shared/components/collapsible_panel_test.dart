// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/collapsible_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_presentation_state.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  for (final direction in CollapseDirection.values) {
    testClient('requests collapse and reopen, leaving state with the owner: ${direction.name}', (tester) async {
      final owner = ValueNotifier(PanelPresentationState.expanded);
      final requests = <PanelPresentationState>[];
      addTearDown(() async {
        tester.binding.detachRootComponent();
        await pumpEventQueue();
        owner.dispose();
      });
      tester.pumpComponent(
        ListenableBuilder(
          listenable: owner,
          builder: (_) => CollapsiblePanel(
            id: 'test-panel',
            label: 'test panel',
            state: owner.value,
            onStateChanged: requests.add,
            collapseDirection: direction,
            child: const div(id: 'panel-child', [.text('Panel content')]),
          ),
        ),
      );

      final toggle = web.document.querySelector('.collapsible-panel-toggle')! as web.HTMLButtonElement;
      expect(toggle.getAttribute('aria-controls'), 'test-panel-content');
      expect(toggle.getAttribute('aria-expanded'), 'true');
      expect(toggle.getAttribute('aria-label'), 'Collapse test panel');
      expect(toggle.textContent, direction == CollapseDirection.up ? 'keyboard_arrow_up' : 'keyboard_arrow_down');
      toggle.focus();
      toggle.click();
      await pumpEventQueue();
      expect(requests, [PanelPresentationState.collapsed]);
      expect(web.document.querySelector('#panel-child'), isNotNull);

      owner.value = requests.single;
      await pumpEventQueue();
      expect(web.document.querySelector('#panel-child'), isNull);
      expect(web.document.querySelector('#test-panel.collapsed'), isNotNull);
      expect(toggle.getAttribute('aria-expanded'), 'false');
      expect(toggle.getAttribute('aria-label'), 'Show test panel');
      expect(toggle.textContent, direction == CollapseDirection.up ? 'keyboard_arrow_down' : 'keyboard_arrow_up');
      expect(web.document.activeElement, toggle);
      expect(requests, hasLength(1));

      toggle.click();
      await pumpEventQueue();
      expect(requests, [PanelPresentationState.collapsed, PanelPresentationState.expanded]);
      owner.value = requests.last;
      await pumpEventQueue();
      expect(web.document.querySelector('#panel-child'), isNotNull);
      expect(toggle.getAttribute('aria-expanded'), 'true');
      expect(web.document.activeElement, toggle);

      owner.value = PanelPresentationState.hidden;
      await pumpEventQueue();
      expect(web.document.querySelector('#test-panel'), isNull);
      expect(web.document.querySelector('#panel-child'), isNull);
      expect(web.document.querySelector('.collapsible-panel-toggle'), isNull);
      expect(requests, hasLength(2));

      owner.value = PanelPresentationState.collapsed;
      await pumpEventQueue();
      expect(web.document.querySelector('#test-panel.collapsed'), isNotNull);
      expect(web.document.querySelector('#panel-child'), isNull);
      owner.value = PanelPresentationState.expanded;
      await pumpEventQueue();
      expect(web.document.querySelector('#panel-child'), isNotNull);
      expect(requests, hasLength(2));
    });
  }
}
