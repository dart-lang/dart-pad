// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/dropdown_menu.dart';
import 'package:dartpad_frontend/features/shared/components/icon_button.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

const _tooltipDelay = Duration(milliseconds: 650);

void main() {
  testClient('touch opens a dropdown without showing a compatibility mouse tooltip', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        trigger: const IconButton(icon: 'apps', label: 'More options', tooltip: 'More options'),
        items: [DropdownMenuItem(label: 'Item', onPressed: () {})],
      ),
    );
    final button = web.document.querySelector('.icon-button')! as web.HTMLButtonElement;

    button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'touch')));
    button.dispatchEvent(web.PointerEvent('pointerdown', web.PointerEventInit(pointerType: 'touch')));
    button.dispatchEvent(web.PointerEvent('pointerup', web.PointerEventInit(pointerType: 'touch')));
    button.dispatchEvent(web.PointerEvent('pointerleave', web.PointerEventInit(pointerType: 'touch')));
    // Touch browsers can emit mouse events even though no mouse is hovering.
    button.dispatchEvent(web.MouseEvent('mouseenter'));
    button.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu'), isNotNull);
    await Future<void>.delayed(_tooltipDelay);
    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });

  for (final pointerType in ['mouse', 'pen']) {
    testClient('$pointerType hover shows a tooltip and leaving hides it', (tester) async {
      tester.pumpComponent(const IconButton(icon: 'apps', tooltip: 'More options'));
      final button = web.document.querySelector('.icon-button')!;

      button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: pointerType)));
      button.dispatchEvent(web.MouseEvent('mouseenter'));
      await Future<void>.delayed(_tooltipDelay);
      expect(web.document.querySelector('.custom-tooltip')?.textContent, 'More options');

      button.dispatchEvent(web.PointerEvent('pointerleave', web.PointerEventInit(pointerType: pointerType)));
      button.dispatchEvent(web.MouseEvent('mouseleave'));
      await pumpEventQueue();
      expect(web.document.querySelector('.custom-tooltip'), isNull);
    });
  }

  testClient('leaving before the hover delay cancels the tooltip', (tester) async {
    tester.pumpComponent(const IconButton(icon: 'apps', tooltip: 'More options'));
    final button = web.document.querySelector('.icon-button')!;

    button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'mouse')));
    button.dispatchEvent(web.MouseEvent('mouseenter'));
    button.dispatchEvent(web.PointerEvent('pointerleave', web.PointerEventInit(pointerType: 'mouse')));
    button.dispatchEvent(web.MouseEvent('mouseleave'));
    await Future<void>.delayed(_tooltipDelay);

    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });

  for (final waitForTooltip in [false, true]) {
    testClient('pointer down cancels a ${waitForTooltip ? 'visible' : 'pending'} tooltip', (tester) async {
      tester.pumpComponent(const IconButton(icon: 'apps', tooltip: 'More options'));
      final button = web.document.querySelector('.icon-button')!;

      button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'mouse')));
      button.dispatchEvent(web.MouseEvent('mouseenter'));
      if (waitForTooltip) {
        await Future<void>.delayed(_tooltipDelay);
        expect(web.document.querySelector('.custom-tooltip'), isNotNull);
      }

      button.dispatchEvent(web.PointerEvent('pointerdown', web.PointerEventInit(pointerType: 'mouse')));
      await pumpEventQueue();
      expect(web.document.querySelector('.custom-tooltip'), isNull);
      await Future<void>.delayed(_tooltipDelay);
      expect(web.document.querySelector('.custom-tooltip'), isNull);
    });
  }
}
