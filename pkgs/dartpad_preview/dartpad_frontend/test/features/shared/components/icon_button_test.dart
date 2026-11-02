// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/dropdown_menu.dart';
import 'package:dartpad_frontend/features/shared/components/icon_button.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

import '../../../pointer_fixture.dart';

const _tooltipDelay = Duration(milliseconds: 650);

void main() {
  testClient('touch activates the button without a delayed hover tooltip', (tester) async {
    var clicks = 0;
    tester.pumpComponent(IconButton(icon: 'expand_more', tooltip: 'Hide bottom panel', onClick: (_) => clicks++));
    await pumpEventQueue();
    final button = web.document.querySelector('button')! as web.HTMLButtonElement;
    touchTap(button);
    expect(clicks, 1);
    await Future<void>.delayed(_tooltipDelay);
    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });

  testClient('touch activation releases button focus', (tester) async {
    tester.pumpComponent(IconButton(icon: 'expand_more', onClick: (_) {}));
    await pumpEventQueue();
    final button = web.document.querySelector('button')! as web.HTMLButtonElement;
    touchTap(button);
    expect(web.document.activeElement, isNot(button));
  });

  testClient('keyboard activation retains button focus', (tester) async {
    var clicks = 0;
    tester.pumpComponent(IconButton(icon: 'expand_more', onClick: (_) => clicks++));
    await pumpEventQueue();
    final button = web.document.querySelector('button')! as web.HTMLButtonElement;
    button.focus();
    button.dispatchEvent(web.MouseEvent('click', web.MouseEventInit(detail: 0, bubbles: true)));
    expect(clicks, 1);
    expect(web.document.activeElement, button);
  });

  testClient('a dropdown trigger without its own action also suppresses touch tooltips', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        trigger: const IconButton(icon: 'apps', label: 'More options', tooltip: 'More options'),
        items: [DropdownMenuItem(label: 'Item', onPressed: () {})],
      ),
    );
    await pumpEventQueue();
    final button = web.document.querySelector('.icon-button')! as web.HTMLButtonElement;
    touchTap(button);
    await pumpEventQueue();
    expect(web.document.querySelector('.dropdown-menu'), isNotNull);
    await Future<void>.delayed(_tooltipDelay);
    expect(web.document.querySelector('.custom-tooltip'), isNull);
    expect(web.document.activeElement, isNot(button));
  });

  testClient('mouse hover still shows tooltips after using touch', (tester) async {
    tester.pumpComponent(IconButton(icon: 'apps', tooltip: 'More options', onClick: (_) {}));
    await pumpEventQueue();
    final button = web.document.querySelector('button')! as web.HTMLButtonElement;
    touchTap(button);
    button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'mouse')));
    button.dispatchEvent(web.MouseEvent('mouseenter'));
    await Future<void>.delayed(_tooltipDelay);
    expect(web.document.querySelector('.custom-tooltip')?.textContent, 'More options');
    button.dispatchEvent(web.PointerEvent('pointerleave', web.PointerEventInit(pointerType: 'mouse')));
    button.dispatchEvent(web.MouseEvent('mouseleave'));
    await pumpEventQueue();
    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });

  testClient('activation cancels a pending mouse tooltip', (tester) async {
    tester.pumpComponent(IconButton(icon: 'expand_more', tooltip: 'Hide bottom panel', onClick: (_) {}));
    await pumpEventQueue();
    final button = web.document.querySelector('button')! as web.HTMLButtonElement;
    button.dispatchEvent(web.PointerEvent('pointerenter', web.PointerEventInit(pointerType: 'mouse')));
    button.dispatchEvent(web.MouseEvent('mouseenter'));
    button.click();
    await Future<void>.delayed(_tooltipDelay);
    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });
}
