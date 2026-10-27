// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/shared/components/tooltip.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  setUp(Tooltip.resetCooldown);

  testClient('renders child directly when message is null or empty', (tester) async {
    tester.pumpComponent(
      const Tooltip(
        child: button([.text('Click me')]),
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.custom-tooltip'), isNull);
    expect(web.document.querySelector('button'), isNotNull);
  });

  testClient('shows tooltip on mouse enter after waitDuration and hides on mouse leave', (tester) async {
    tester.pumpComponent(
      const Tooltip(
        message: 'Helpful message',
        waitDuration: Duration(milliseconds: 200),
        cooldownDuration: Duration(milliseconds: 200),
        child: button([.text('Target')]),
      ),
    );
    await pumpEventQueue();

    final target = web.document.querySelector('button')! as web.HTMLElement;
    expect(web.document.querySelector('.custom-tooltip'), isNull);

    target.dispatchEvent(web.MouseEvent('mouseenter'));
    expect(web.document.querySelector('.custom-tooltip'), isNull);

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await pumpEventQueue();

    final tooltip = web.document.querySelector('.custom-tooltip');
    expect(tooltip, isNotNull);
    expect(tooltip!.textContent, 'Helpful message');

    target.dispatchEvent(web.MouseEvent('mouseleave'));
    await pumpEventQueue();
    expect(web.document.querySelector('.custom-tooltip'), isNull);
  });

  testClient('renders rich tooltip with title and description on newline', (tester) async {
    tester.pumpComponent(
      const Tooltip(
        message: 'Main Title\nDetailed description line',
        waitDuration: Duration(milliseconds: 20),
        cooldownDuration: Duration(milliseconds: 50),
        child: button([.text('Target')]),
      ),
    );
    await pumpEventQueue();

    final target = web.document.querySelector('button')! as web.HTMLElement;
    target.dispatchEvent(web.MouseEvent('mouseenter'));

    await Future<void>.delayed(const Duration(milliseconds: 30));
    await pumpEventQueue();

    final tooltip = web.document.querySelector('.custom-tooltip.rich-tooltip');
    expect(tooltip, isNotNull);
    expect(tooltip!.querySelector('.tooltip-title')!.textContent, 'Main Title');
    expect(tooltip.querySelector('.tooltip-desc')!.textContent, 'Detailed description line');
  });

  testClient('shows immediately within cooldown window', (tester) async {
    tester.pumpComponent(
      const Tooltip(
        message: 'First tooltip',
        waitDuration: Duration(milliseconds: 40),
        cooldownDuration: Duration(milliseconds: 200),
        child: button([.text('First')]),
      ),
    );
    await pumpEventQueue();

    final target = web.document.querySelector('button')! as web.HTMLElement;
    target.dispatchEvent(web.MouseEvent('mouseenter'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await pumpEventQueue();

    expect(web.document.querySelector('.custom-tooltip'), isNotNull);

    target.dispatchEvent(web.MouseEvent('mouseleave'));
    await pumpEventQueue();
    expect(web.document.querySelector('.custom-tooltip'), isNull);

    target.dispatchEvent(web.MouseEvent('mouseenter'));
    await pumpEventQueue();
    expect(web.document.querySelector('.custom-tooltip'), isNotNull);
  });
}
