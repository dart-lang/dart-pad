// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/shared/components/dropdown_menu.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('opens and closes dropdown menu on trigger click', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        items: [
          DropdownMenuItem(label: 'Item 1', onPressed: () {}),
          DropdownMenuItem(label: 'Item 2', onPressed: () {}),
        ],
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNotNull);
    final items = web.document.querySelectorAll('.dropdown-menu-item');
    expect(items.length, 2);

    trigger.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
  });

  testClient('renders leadingIcon, trailingIcon, and active state for selected items', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        items: [
          DropdownMenuItem(
            label: 'Selected Item',
            leadingIcon: 'check_circle',
            trailingIcon: 'chevron_right',
            isSelected: true,
            onPressed: () {},
          ),
          DropdownMenuItem(
            label: 'Normal Item',
            onPressed: () {},
          ),
        ],
      ),
    );
    await pumpEventQueue();

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.dropdown-menu-item');
    expect(items.length, 2);

    final firstItem = items.item(0) as web.HTMLElement;
    expect(firstItem.className, contains('active'));
    expect(firstItem.textContent, contains('check_circle'));
    expect(firstItem.textContent, contains('Selected Item'));
    expect(firstItem.textContent, contains('chevron_right'));

    final secondItem = items.item(1) as web.HTMLElement;
    expect(secondItem.className, isNot(contains('active')));
  });

  testClient('invokes onPressed and closes menu on item click', (tester) async {
    var itemClicked = false;
    tester.pumpComponent(
      DropdownMenu(
        items: [
          DropdownMenuItem(
            label: 'Click Me',
            onPressed: () => itemClicked = true,
          ),
        ],
      ),
    );
    await pumpEventQueue();

    (web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement).click();
    await pumpEventQueue();

    final item = web.document.querySelector('.dropdown-menu-item') as web.HTMLButtonElement;
    item.click();
    await pumpEventQueue();

    expect(itemClicked, isTrue);
    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
  });

  testClient('does not open menu when disabled is true', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        disabled: true,
        items: [
          DropdownMenuItem(label: 'Disabled Option', onPressed: () {}),
        ],
      ),
    );
    await pumpEventQueue();

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
  });
}
