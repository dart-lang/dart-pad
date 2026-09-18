// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/persistence/project_conflict_dialog.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('focus stays in the dialog while actions are busy and returns to Keep my version', (tester) async {
    Component dialog({required bool busy}) => Component.fragment([
      const button(id: 'background-button', [.text('Background')]),
      ProjectConflictDialog(busy: busy, onUseLatest: () {}, onKeepVersion: () {}),
    ]);
    tester.pumpComponent(dialog(busy: false));
    await pumpEventQueue();
    expect(web.document.activeElement!.textContent, 'Keep my version');

    tester.pumpComponent(dialog(busy: true));
    await pumpEventQueue();
    final element = web.document.querySelector('#project-conflict-dialog')! as web.HTMLDialogElement;
    expect(element.open, isTrue);
    expect(element.getAttribute('aria-busy'), 'true');
    expect((element.querySelector('button')! as web.HTMLButtonElement).disabled, isTrue);
    expect(element.contains(web.document.activeElement), isTrue);
    for (final shift in [false, true]) {
      final tab = web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Tab', shiftKey: shift, bubbles: true, cancelable: true),
      );
      web.document.activeElement!.dispatchEvent(tab);
      expect(tab.defaultPrevented, isTrue);
      expect(element.contains(web.document.activeElement), isTrue);
    }
    tester.pumpComponent(dialog(busy: false));
    await pumpEventQueue();
    expect(element.getAttribute('aria-busy'), isNull);
    expect(web.document.activeElement!.textContent, 'Keep my version');
  });
}
