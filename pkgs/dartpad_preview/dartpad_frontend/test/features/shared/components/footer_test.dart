// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/footer.dart';
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
}
