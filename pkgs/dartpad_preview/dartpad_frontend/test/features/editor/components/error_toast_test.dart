// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:async';

import 'package:dartpad_frontend/features/editor/components/error_toast.dart';
import 'package:dartpad_frontend/features/shared/app_event_bus.dart';
import 'package:dartpad_frontend/features/shared/components/context_menu.dart';
import 'package:dartpad_frontend/features/shared/events/error_toast_event.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  testClient('shows an error toast and dismisses it after the configured duration', (tester) async {
    final events = AppEventBus();
    tester.pumpComponent(
      ErrorToast(
        events: events,
        displayDuration: const Duration(milliseconds: 500),
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.editor-error-toast'), isNull);

    events.dispatch(const ErrorToastEvent('Saving failed, try again'));
    await pumpEventQueue();

    final toast = web.document.querySelector('.editor-error-toast');
    expect(toast, isNotNull);
    expect(toast!.textContent, contains('Saving failed, try again'));
    expect(toast.getAttribute('role'), 'alert');

    await Future<void>.delayed(const Duration(milliseconds: 550));
    await pumpEventQueue();

    expect(web.document.querySelector('.editor-error-toast'), isNull);
    await events.dispose();
  });

  testClient('remounts toast on consecutive errors to restart animation', (tester) async {
    final events = AppEventBus();
    tester.pumpComponent(
      ErrorToast(
        events: events,
        displayDuration: const Duration(seconds: 1),
      ),
    );
    await pumpEventQueue();

    events.dispatch(const ErrorToastEvent('First error'));
    await pumpEventQueue();
    final firstToast = web.document.querySelector('.editor-error-toast');
    expect(firstToast, isNotNull);
    expect(firstToast!.textContent, contains('First error'));

    await Future<void>.delayed(const Duration(milliseconds: 600));
    events.dispatch(const ErrorToastEvent('Second error'));
    await pumpEventQueue();

    final secondToast = web.document.querySelector('.editor-error-toast');
    expect(secondToast, isNotNull);
    expect(firstToast.isConnected, isFalse);
    expect(secondToast!.textContent, contains('Second error'));

    await Future<void>.delayed(const Duration(milliseconds: 600));
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-error-toast'), isNotNull);

    await Future<void>.delayed(const Duration(milliseconds: 500));
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-error-toast'), isNull);
    await events.dispose();
  });

  testClient('shows an error while a context menu closes without corrupting the render tree', (tester) async {
    final events = AppEventBus();
    final contextMenu = ContextMenuController();

    tester.pumpComponent(
      div([
        ErrorToast(events: events),
        ListenableBuilder(
          listenable: contextMenu,
          builder: (context) => ContextMenu(
            x: contextMenu.x,
            y: contextMenu.y,
            items: contextMenu.items,
            isOpen: contextMenu.isOpen,
            onClose: contextMenu.hide,
          ),
        ),
      ]),
    );
    await pumpEventQueue();

    contextMenu.show(10, 10, [
      ContextMenuItem(
        label: 'Paste',
        onPressed: () => events.dispatch(const ErrorToastEvent('Clipboard access denied')),
      ),
    ]);
    await pumpEventQueue();

    final paste = web.document.querySelector('.context-menu-item') as web.HTMLButtonElement;
    paste.click();
    await pumpEventQueue();

    expect(contextMenu.isOpen, isFalse);
    expect(web.document.querySelector('.editor-error-toast')?.textContent, contains('Clipboard access denied'));

    contextMenu.dispose();
    await events.dispose();
  });
}
