// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:dartpad_frontend/features/shared/analyzer_status.dart';
import 'package:dartpad_frontend/features/shared/components/dropdown_menu.dart';
import 'package:dartpad_frontend/features/shared/components/footer.dart';
import 'package:dartpad_frontend/features/shared/components/icon_button.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:dartpad_frontend/sdks.g.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

void main() {
  late TaskStatusController taskStatus;

  setUp(() {
    taskStatus = TaskStatusController();
    final originalWidth = _getOwnPropertyDescriptor(web.window, 'innerWidth'.toJS);
    addTearDown(() {
      if (originalWidth == null) {
        web.window.delete('innerWidth'.toJS);
      } else {
        _defineProperty(web.window, 'innerWidth'.toJS, originalWidth);
      }
    });
    _setWidth(1200);
  });

  tearDown(() {
    taskStatus.dispose();
  });

  testClient('renders desktop footer with privacy and feedback links', (tester) {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        isSmallScreen: false,
        onOpenShortcuts: () {},
      ),
    );

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 2);

    final status = web.document.querySelector('.task-status-trigger');
    expect(status?.textContent, contains('Ready'));
  });

  testClient('renders small-screen footer without privacy and feedback links', (tester) {
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        isSmallScreen: true,
        onOpenShortcuts: () {},
      ),
    );

    final links = web.document.querySelectorAll('.app-footer-link');
    expect(links.length, 0);

    final status = web.document.querySelector('.task-status-trigger');
    expect(status?.textContent, contains('Ready'));
  });

  testClient('lists Flutter and Dart SDKs in two columns of one selector', (tester) async {
    final flutter = availableSdks.firstWhere((sdk) => sdk.isFlutter);
    final dart = availableSdks.firstWhere((sdk) => !sdk.isFlutter);
    var selected = flutter;
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        currentSdk: flutter,
        onSelectSdk: (sdk) => selected = sdk,
        onOpenShortcuts: () {},
      ),
    );

    final sdkButton = web.document.querySelector('.app-footer-sdk-trigger') as web.HTMLButtonElement;
    expect(sdkButton.textContent, _triggerText(flutter));
    expect(sdkButton.querySelectorAll('.sdk-logo').length, 2);

    sdkButton.click();
    await pumpEventQueue();
    final columns = _items(web.document.querySelectorAll('.dropdown-menu-columns ul'));
    expect(columns.length, 2);
    expect(columns[0].querySelector('.dropdown-menu-divider')?.textContent, 'Flutter');
    expect(columns[0].querySelector('.dropdown-menu-divider .sdk-logo'), isNotNull);
    expect(columns[1].querySelector('.dropdown-menu-divider')?.textContent, 'Dart');
    expect(columns[1].querySelector('.dropdown-menu-divider .sdk-logo'), isNotNull);
    for (final (index, isFlutter) in [(0, true), (1, false)]) {
      final labels = [
        for (final item in _items(columns[index].querySelectorAll('.dropdown-menu-item'))) _label(item),
      ];
      expect(labels, [
        for (final sdk in availableSdks.where((sdk) => sdk.isFlutter == isFlutter).toList().reversed) sdk.menuLabel,
      ]);
    }
    expect(
      web.document.querySelector('.dropdown-menu-item.active .dropdown-menu-item-name')?.textContent,
      flutter.menuLabel,
    );
    final dartItem = _itemFor(_items(web.document.querySelectorAll('.dropdown-menu-item')), dart);
    (dartItem as web.HTMLButtonElement).click();
    await pumpEventQueue();
    expect(selected, dart);
  });

  testClient('selects any SDK across kinds and channels', (tester) async {
    final currentSdk = ValueNotifier(availableSdks.first);
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      currentSdk.dispose();
    });
    tester.pumpComponent(
      ValueListenableBuilder(
        listenable: currentSdk,
        builder: (_, sdk) => Footer(
          taskStatus: taskStatus,
          currentSdk: sdk,
          onSelectSdk: (sdk) => currentSdk.value = sdk,
          onOpenShortcuts: () {},
        ),
      ),
    );

    for (final target in [...availableSdks.skip(1), availableSdks.first]) {
      (web.document.querySelector('.app-footer-sdk-trigger')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      final items = _items(web.document.querySelectorAll('.dropdown-menu-item'));
      expect(items.length, availableSdks.length);
      final item = _itemFor(items, target);
      (item as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(currentSdk.value, target);
      expect(web.document.querySelector('.app-footer-sdk-label')?.textContent, _triggerText(target));
    }
  });

  testClient('disables SDK selection during workspace preparation', (tester) async {
    tester.pumpComponent(
      Footer(taskStatus: taskStatus, currentSdk: defaultSdk, onOpenShortcuts: () {}),
    );
    final button = web.document.querySelector('.app-footer-sdk-trigger')! as web.HTMLButtonElement;
    expect(button.disabled, isTrue);
    button.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.dropdown-menu'), isNull);
  });

  for (final sdk in availableSdks) {
    testClient('shows compact ${sdk.name} ${sdk.channel} control on small screens', (tester) async {
      _setWidth(390);
      tester.pumpComponent(
        Footer(
          taskStatus: taskStatus,
          isSmallScreen: true,
          currentSdk: sdk,
          onSelectSdk: (_) {},
          onOpenShortcuts: () {},
        ),
      );

      final trigger = web.document.querySelector('.app-footer-sdk-trigger')! as web.HTMLButtonElement;
      expect(trigger.textContent, isEmpty);
      expect(trigger.querySelectorAll('.sdk-logo').length, 1);
      expect(trigger.getAttribute('aria-label'), contains(sdk.displayName));

      trigger.click();
      await pumpEventQueue();
      expect(web.document.querySelector('.dropdown-menu')?.textContent, contains(sdk.menuLabel));
    });
  }

  for (final width in [320, 390, 499, 500, 600, 865, 866, 1200]) {
    testClient('uses the appropriate footer layout without overlap at ${width}px', (tester) async {
      _setWidth(width);
      taskStatus.startTask(TaskKind.startingPreview);
      tester.pumpComponent(
        div([
          Style(styles: [...Footer.styles, ...DropdownMenu.styles, ...IconButton.styles]),
          div(
            styles: Styles(width: width.px),
            [
              Footer(
                taskStatus: taskStatus,
                isSmallScreen: width < 866,
                currentSdk: availableSdks.firstWhere((sdk) => sdk.isFlutter),
                onSelectSdk: (_) {},
                onOpenShortcuts: () {},
              ),
            ],
          ),
        ]),
      );

      final footer = web.document.querySelector('.app-footer')!;
      final flutter = availableSdks.firstWhere((sdk) => sdk.isFlutter);
      expect(
        footer.querySelector('.app-footer-sdk-trigger')!.textContent,
        width < 500 ? isEmpty : _triggerText(flutter),
      );
      expect(footer.querySelectorAll('.app-footer-link').length, width < 866 ? 0 : 2);
      final status = footer.querySelector('.task-status-trigger')!.getBoundingClientRect();
      final sdk = footer.querySelector('.app-footer-sdk-trigger')!.getBoundingClientRect();
      expect(status.right, lessThanOrEqualTo(sdk.left));
      expect(sdk.right, lessThanOrEqualTo(footer.getBoundingClientRect().right));
    });
  }

  testClient('updates SDK labels when crossing the compact breakpoint', (tester) async {
    final sdk = availableSdks.first;
    _setWidth(499);
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        isSmallScreen: true,
        currentSdk: sdk,
        onSelectSdk: (_) {},
        onOpenShortcuts: () {},
      ),
    );

    for (final width in [499, 500, 499]) {
      _setWidth(width);
      web.window.dispatchEvent(web.Event('resize'));
      await pumpEventQueue();
      expect(
        web.document.querySelector('.app-footer-sdk-trigger')!.textContent,
        width < 500 ? isEmpty : _triggerText(sdk),
      );
      expect(web.document.querySelector('.app-footer-link'), isNull);
    }
  });

  testClient('opens shortcuts dialog through the callback', (tester) async {
    var opened = false;
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        isSmallScreen: false,
        onOpenShortcuts: () => opened = true,
      ),
    );

    final keyboardBtn = web.document.querySelector('.app-footer-buttons button') as web.HTMLButtonElement?;
    expect(keyboardBtn, isNotNull);
    keyboardBtn?.click();
    await pumpEventQueue();
    expect(opened, isTrue);
  });

  testClient('shows active and completed tasks in the status popover', (tester) async {
    final completed = taskStatus.startTask(TaskKind.initializingDartPadWorker);
    completed.succeed();
    taskStatus.startTask(
      TaskKind.pubGet,
      label: 'Pub get in /',
      scope: '/',
    );
    tester.pumpComponent(
      Footer(
        taskStatus: taskStatus,
        statusMessage: 'Could not save all files.',
        onOpenShortcuts: () {},
      ),
    );

    final anchor = web.document.querySelector('.task-status-anchor')!;
    anchor.dispatchEvent(web.MouseEvent('mouseenter'));
    await pumpEventQueue();

    final rows = web.document.querySelectorAll('.task-status-table tr');
    expect(rows.length, 2);
    expect(rows.item(0)?.textContent, contains('Pub get in /'));
    expect(rows.item(1)?.textContent, contains('Initializing DartPad worker'));
    expect(web.document.querySelector('.app-footer-message')?.textContent, 'Could not save all files.');
  });

  testClient('shows analyzer startup and change analysis in the task status bar', (tester) async {
    final analyzerStatus = AnalyzerStatusController(taskStatus);
    tester.pumpComponent(
      Footer(taskStatus: taskStatus, onOpenShortcuts: () {}),
    );

    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Ready'));

    analyzerStatus.beginInitialization();
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Starting analyzer'));

    analyzerStatus.update(isAnalyzing: false);
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Starting analyzer'));

    analyzerStatus.update(isAnalyzing: true);
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Analyzing'));

    analyzerStatus.update(isAnalyzing: false);
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Analyzing'));

    analyzerStatus.markUnavailable();
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-trigger')?.textContent, contains('Analyzing'));
    expect(web.document.querySelector('.task-status-trigger .task-status-icon.failed'), isNotNull);

    analyzerStatus.dispose();
  });

  testClient('opens by focus or click and closes with Escape', (tester) async {
    taskStatus.startTask(TaskKind.startingAnalyzer);
    tester.pumpComponent(
      Footer(taskStatus: taskStatus, onOpenShortcuts: () {}),
    );

    final trigger = web.document.querySelector('.task-status-trigger') as web.HTMLButtonElement;
    // Chrome may not move focus in a background CI tab. Exercise the focus
    // event handled by the component directly.
    trigger.dispatchEvent(web.FocusEvent('focusin', web.FocusEventInit(bubbles: true)));
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNotNull);

    web.document.dispatchEvent(
      web.KeyboardEvent(
        'keydown',
        web.KeyboardEventInit(key: 'Escape', bubbles: true, cancelable: true),
      ),
    );
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNull);

    trigger.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.task-status-popover'), isNotNull);
  });
}

// The trigger shows logos instead of the SDK names, so only versions and the channel are text.
String _triggerText(SdkInfo sdk) =>
    '${sdk.shortFlutterVersion == null ? '' : '${sdk.shortFlutterVersion} •'}${sdk.shortDartVersion}${sdk.channel ?? ''}';

// Menu items of beta and main/dev share a version label, so the channel tag tells them apart.
web.Element _itemFor(Iterable<web.Element> items, SdkInfo sdk) => items.singleWhere(
  (item) => _label(item) == sdk.menuLabel && (item.querySelector('.sdk-tag')?.textContent ?? '') == (sdk.channel ?? ''),
);

String _label(web.Element item) => item.querySelector('.dropdown-menu-item-name')!.textContent!;

List<web.Element> _items(web.NodeList nodes) => [for (var i = 0; i < nodes.length; i++) nodes.item(i)! as web.Element];

// Drive the same viewport input and resize event used by Footer.
void _setWidth(int width) {
  _defineProperty(web.window, 'innerWidth'.toJS, {'configurable': true, 'value': width}.jsify() as JSObject);
}

@JS('Object.defineProperty')
external void _defineProperty(JSObject target, JSString property, JSObject descriptor);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getOwnPropertyDescriptor(JSObject target, JSString property);
