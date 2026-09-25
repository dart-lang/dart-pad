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

    // Initial state: menu panel is not rendered.
    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);

    // Click trigger to open menu.
    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNotNull);
    final items = web.document.querySelectorAll('.dropdown-menu-item');
    expect(items.length, 2);
    expect((items.item(0) as web.HTMLElement).textContent, contains('Item 1'));
    expect((items.item(1) as web.HTMLElement).textContent, contains('Item 2'));

    // Click trigger again to close menu.
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
          DropdownMenuItem(label: 'Normal Item', isSelected: false, onPressed: () {}),
        ],
      ),
    );

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

  testClient('renders nav.dropdown-menu with semantic ul/li structure and items', (tester) async {
    tester.pumpComponent(
      DropdownMenu(
        items: [
          DropdownMenuItem(
            label: 'Option 1',
            leadingImage: 'images/dart-192.svg',
            onPressed: () {},
          ),
        ],
      ),
    );
    await pumpEventQueue();

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    final nav = web.document.querySelector('nav.dropdown-menu');
    expect(nav, isNotNull);
    expect(nav!.getAttribute('role'), 'menu');

    final list = nav.querySelector('ul');
    expect(list, isNotNull);

    final listItem = list!.querySelector('li');
    expect(listItem, isNotNull);

    final itemButton = listItem!.querySelector('button.dropdown-menu-item') as web.HTMLButtonElement?;
    expect(itemButton, isNotNull);
    expect(itemButton!.getAttribute('role'), 'menuitem');

    final logo = itemButton.querySelector('img.dropdown-menu-item-image') as web.HTMLImageElement?;
    expect(logo, isNotNull);
    expect(logo!.src, contains('images/dart-192.svg'));

    final name = itemButton.querySelector('.dropdown-menu-item-name');
    expect(name, isNotNull);
    expect(name!.textContent, 'Option 1');
  });

  testClient('invokes onPressed and closes menu on item click', (tester) async {
    var itemClicked = false;
    tester.pumpComponent(
      DropdownMenu(
        items: [
          DropdownMenuItem(
            label: 'Click Me',
            onPressed: () {
              itemClicked = true;
            },
          ),
        ],
      ),
    );

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
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
        items: [DropdownMenuItem(label: 'Disabled Item', onPressed: () {})],
      ),
    );

    final trigger = web.document.querySelector('.dropdown-menu-default-trigger') as web.HTMLButtonElement;
    trigger.click();
    await pumpEventQueue();

    expect(web.document.querySelector('.dropdown-menu-panel'), isNull);
  });
}
