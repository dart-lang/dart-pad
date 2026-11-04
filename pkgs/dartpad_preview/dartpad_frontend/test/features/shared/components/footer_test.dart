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

  testClient('shows separate SDK and beta channel controls', (tester) async {
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
    expect(sdkButton.textContent, contains(flutter.displayName));
    final channel = web.document.querySelector('.app-footer-channel')!;
    expect(channel.textContent, contains('Beta channel'));
    expect(channel.tagName, 'SPAN');
    expect(channel.hasAttribute('title'), isFalse);

    sdkButton.click();
    await pumpEventQueue();
    final items = web.document.querySelectorAll('.dropdown-menu-item');
    expect(items.item(0)?.textContent, contains(flutter.displayName));
    final dartItem =
        [
              for (var i = 0; i < items.length; i++) items.item(i)!,
            ].firstWhere((item) => item.textContent!.trim() == dart.displayName)
            as web.HTMLButtonElement;
    dartItem.click();
    await pumpEventQueue();
    expect(selected, dart);
  });

  testClient('updates the channel indicator with the current SDK', (tester) async {
    final currentChannel = ValueNotifier<String?>(null);
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      currentChannel.dispose();
    });
    tester.pumpComponent(
      ValueListenableBuilder(
        listenable: currentChannel,
        builder: (_, channel) => Footer(
          taskStatus: taskStatus,
          currentSdk: SdkInfo(id: 'dart', name: 'Dart', path: 'dart/', dartVersion: '3.14.0', channel: channel),
          onOpenShortcuts: () {},
        ),
      ),
    );

    for (final (channel, label) in [('stable', 'Stable channel'), ('beta', 'Beta channel'), (null, null)]) {
      currentChannel.value = channel;
      await pumpEventQueue();

      final indicator = web.document.querySelector('.app-footer-channel');
      if (label == null) {
        expect(indicator, isNull);
      } else {
        expect(indicator?.textContent, contains(label));
        expect(indicator?.tagName, 'SPAN');
      }
    }
  });

  for (final sdk in availableSdks) {
    testClient('shows compact ${sdk.name} controls on small screens', (tester) async {
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
      expect(trigger.textContent, sdk.name);
      expect(trigger.textContent, isNot(contains(sdk.displayName)));
      expect(trigger.querySelector('.app-footer-info-icon'), isNotNull);
      expect(trigger.getAttribute('aria-label'), contains(sdk.displayName));
      final channel = web.document.querySelector('.app-footer-channel')!;
      expect(channel.querySelector('.material-symbols-outlined')?.textContent, 'tune');
      expect(channel.getAttribute('aria-label'), 'Beta channel');
      expect(channel.querySelector('.app-footer-channel-label'), isNull);

      trigger.click();
      await pumpEventQueue();
      expect(web.document.querySelector('.dropdown-menu')?.textContent, contains(sdk.displayName));
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
        width < 500 ? flutter.name : flutter.displayName,
      );
      expect(footer.querySelector('.app-footer-channel-label'), width < 500 ? isNull : isNotNull);
      expect(footer.querySelectorAll('.app-footer-link').length, width < 866 ? 0 : 2);
      final status = footer.querySelector('.task-status-trigger')!.getBoundingClientRect();
      final sdk = footer.querySelector('.app-footer-sdk-trigger')!.getBoundingClientRect();
      final channel = footer.querySelector('.app-footer-channel')!.getBoundingClientRect();
      expect(status.right, lessThanOrEqualTo(sdk.left));
      expect(sdk.right, lessThanOrEqualTo(channel.left));
      expect(channel.right, lessThanOrEqualTo(footer.getBoundingClientRect().right));
    });
  }

  testClient('updates SDK and channel labels when crossing the compact breakpoint', (tester) async {
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
        width < 500 ? sdk.name : sdk.displayName,
      );
      expect(web.document.querySelector('.app-footer-channel-label'), width < 500 ? isNull : isNotNull);
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

// Drive the same viewport input and resize event used by Footer.
void _setWidth(int width) {
  _defineProperty(web.window, 'innerWidth'.toJS, {'configurable': true, 'value': width}.jsify() as JSObject);
}

@JS('Object.defineProperty')
external void _defineProperty(JSObject target, JSString property, JSObject descriptor);

@JS('Object.getOwnPropertyDescriptor')
external JSObject? _getOwnPropertyDescriptor(JSObject target, JSString property);
