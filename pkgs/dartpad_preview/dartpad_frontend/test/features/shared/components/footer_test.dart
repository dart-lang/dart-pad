// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/footer.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('renders desktop footer with privacy and feedback links', (tester) {
    tester.pumpComponent(const Footer(statusLabel: 'Ready', isSmallScreen: false));

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 2);

    final status = web.document.querySelector('.app-footer-status');
    expect(status?.textContent, 'Ready');
  });

  testClient('renders small-screen footer without privacy and feedback links', (tester) {
    tester.pumpComponent(const Footer(statusLabel: 'Ready', isSmallScreen: true));

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 0);

    final status = web.document.querySelector('.app-footer-status');
    expect(status?.textContent, 'Ready');
  });

  testClient('opens shortcuts dialog and toggles show more shortcuts', (tester) async {
    tester.pumpComponent(const Footer(statusLabel: 'Ready', isMobile: false));

    // Initially dialog is not in the DOM.
    expect(web.document.querySelector('.shortcuts-dialog'), isNull);

    // Click keyboard shortcuts button.
    final keyboardBtn = web.document.querySelector('.app-footer-buttons button') as web.HTMLButtonElement?;
    expect(keyboardBtn, isNotNull);
    keyboardBtn?.click();
    await pumpEventQueue();

    final dialog = web.document.querySelector('.shortcuts-dialog');
    expect(dialog, isNotNull);

    // Verify primary shortcuts are present
    // (5 refactoring + 4 editing + 2 search = 11 rows).
    var rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, 11);

    // Toggle button is present.
    final toggleBtn = web.document.querySelector('.shortcuts-dialog-toggle-btn') as web.HTMLButtonElement?;
    expect(toggleBtn, isNotNull);
    expect(toggleBtn?.textContent, contains('Show more shortcuts'));

    // Expand show more.
    toggleBtn?.click();
    await pumpEventQueue();

    // All shortcut rows are visible
    // (11 primary + 1 refactoring + 5 editing + 4 search + 5 autocomplete = 26).
    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, 26);
    expect(toggleBtn?.textContent, contains('Show fewer shortcuts'));

    // Collapse show more.
    toggleBtn?.click();
    await pumpEventQueue();

    rows = web.document.querySelectorAll('.shortcuts-dialog-row');
    expect(rows.length, 11);
  });

  testClient('footer status update does not dismiss active shortcuts dialog', (tester) async {
    late void Function(String) setStatus;
    tester.pumpComponent(_StatusHolder(onController: (fn) => setStatus = fn));

    // Open dialog.
    final keyboardBtn = web.document.querySelector('.app-footer-buttons button') as web.HTMLButtonElement?;
    keyboardBtn?.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);

    // Update status to 'Done' from parent.
    setStatus('Done');
    await pumpEventQueue();

    // Dialog must still be open.
    expect(web.document.querySelector('.shortcuts-dialog'), isNotNull);
    final status = web.document.querySelector('.app-footer-status');
    expect(status?.textContent, 'Done');
  });
}

class _StatusHolder extends StatefulComponent {
  const _StatusHolder({required this.onController});
  final void Function(void Function(String)) onController;

  @override
  State<_StatusHolder> createState() => _StatusHolderState();
}

class _StatusHolderState extends State<_StatusHolder> {
  String _status = 'Analyzing project...';

  @override
  void initState() {
    super.initState();
    component.onController((newStatus) {
      setState(() {
        _status = newStatus;
      });
    });
  }

  @override
  Component build(BuildContext context) {
    return Footer(statusLabel: _status, isMobile: false);
  }
}
