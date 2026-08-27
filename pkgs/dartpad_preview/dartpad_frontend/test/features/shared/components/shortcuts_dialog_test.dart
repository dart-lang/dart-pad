// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/shortcut_definitions.dart';
import 'package:dartpad_frontend/features/shared/components/shortcuts_dialog.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('triggers onClose on Escape keydown', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));
    await pumpEventQueue();

    final closeButton = web.document.querySelector(
      '.shortcuts-dialog-backdrop [aria-label="Close shortcuts dialog"]',
    );
    closeButton!.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();
    expect(closed, isTrue);
  });

  testClient('renders shortcuts dialog and triggers onClose on close button click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final dialog = web.document.querySelector('.shortcuts-dialog');
    expect(dialog, isNotNull);

    // Primary shortcut rows should match shortcut definitions.
    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);

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
    expect(rows.length, allShortcutCount);
    expect(toggleBtn?.textContent, contains('Show fewer shortcuts'));

    // Collapse
    toggleBtn?.click();
    await pumpEventQueue();

    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, primaryShortcutCount);
  });

  testClient('triggers onClose on backdrop click', (tester) async {
    var closed = false;
    tester.pumpComponent(ShortcutsDialog(onClose: () => closed = true));

    final backdrop = web.document.querySelector('.shortcuts-dialog-backdrop') as web.HTMLElement?;
    expect(backdrop, isNotNull);
    backdrop?.click();
    expect(closed, isTrue);
  });
}
