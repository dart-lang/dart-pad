// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/shortcuts_dialog.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('renders shortcuts dialog and triggers onClose on close button click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final dialog = web.document.querySelector('.shortcuts-dialog');
    expect(dialog, isNotNull);

    // Initial 11 primary shortcut rows
    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, 11);

    final closeBtn = dialog?.querySelector('[aria-label="Close shortcuts dialog"]') as web.HTMLButtonElement?;
    expect(closeBtn, isNotNull);
    closeBtn?.click();
    expect(closed, isTrue);
  });

  testClient('toggles between primary and extended shortcut list', (tester) async {
    tester.pumpComponent(ShortcutsDialog(onClose: () {}));

    final toggleBtn = web.document.querySelector('.shortcuts-dialog-toggle-btn') as web.HTMLButtonElement?;
    expect(toggleBtn, isNotNull);
    expect(toggleBtn?.textContent, contains('Show more shortcuts'));

    // Expand
    toggleBtn?.click();
    await pumpEventQueue();

    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, greaterThan(15));
    expect(toggleBtn?.textContent, contains('Show fewer shortcuts'));

    // Collapse
    toggleBtn?.click();
    await pumpEventQueue();

    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, 11);
  });

  testClient('triggers onClose on backdrop click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final backdrop = web.document.querySelector('.shortcuts-dialog-backdrop') as web.HTMLElement?;
    expect(backdrop, isNotNull);
    backdrop?.click();
    expect(closed, isTrue);
  });

  testClient('triggers onClose on Escape keydown', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    web.window.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    expect(closed, isTrue);
  });
}
