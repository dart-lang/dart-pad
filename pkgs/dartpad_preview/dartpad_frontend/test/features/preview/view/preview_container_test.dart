// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view/preview_container.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:dartpad_frontend/features/shared/task_status.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

class FakePreviewViewModel extends ChangeNotifier implements PreviewViewModel {
  @override
  final web.Element containerElement = web.document.createElement('div')..className = 'preview';

  @override
  PreviewState state = PreviewRunning('lib/main.dart');

  @override
  bool isRunning = true;

  @override
  bool isFlutter = true;

  @override
  bool canStart = false;

  @override
  bool canRestart = true;

  @override
  bool canHotReload = true;

  @override
  bool canStop = true;

  @override
  List<ConsoleEntry> appLogs = const [];

  void setRunning(bool value) {
    isRunning = value;
    state = value ? PreviewRunning('lib/main.dart') : PreviewInitial();
    canStart = !value;
    canRestart = value;
    canHotReload = value;
    canStop = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakePreviewViewModel preview;
  late TaskStatusController taskStatus;

  setUp(() {
    preview = FakePreviewViewModel();
    taskStatus = TaskStatusController();

    final style = web.document.createElement('style') as web.HTMLStyleElement;
    style.id = 'test-preview-style';
    style.textContent = '''
      .preview-container {
        display: flex;
        flex-direction: column;
        flex: 1;
        height: 100%;
      }
      .preview-content {
        flex: 1;
        width: 100%;
        height: 100%;
      }
    ''';
    web.document.head!.appendChild(style);
  });

  tearDown(() {
    web.document.getElementById('test-preview-style')?.remove();
    taskStatus.dispose();
    preview.dispose();
  });

  Component buildContainer({
    FakePreviewViewModel? customPreview,
    String width = '1000px',
    String height = '1000px',
  }) {
    return div(
      attributes: {
        'style': 'display: flex; flex-direction: column; width: $width; height: $height;',
      },
      [
        PreviewContainer(
          preview: customPreview ?? preview,
          taskStatus: taskStatus,
          activeFile: 'lib/main.dart',
          onOpenConsole: () {},
        ),
      ],
    );
  }

  web.HTMLButtonElement? findRotateButton() {
    final buttons = web.document.querySelectorAll('.preview-controls .icon-button');
    for (var i = 0; i < buttons.length; i++) {
      final btn = buttons.item(i) as web.HTMLButtonElement;
      if (btn.textContent?.contains('screen_rotation') ?? false) {
        return btn;
      }
    }
    return null;
  }

  web.HTMLButtonElement findDropdownTrigger() {
    return web.document.querySelector('.device-dropdown-trigger')! as web.HTMLButtonElement;
  }

  Future<void> selectDropdownOption(String title) async {
    final trigger = findDropdownTrigger();
    trigger.click();
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.device-dropdown-item');
    for (var i = 0; i < items.length; i++) {
      final item = items.item(i) as web.HTMLElement;
      if (item.textContent?.contains(title) ?? false) {
        item.click();
        await pumpEventQueue();
        return;
      }
    }
    throw StateError('Option "$title" not found in dropdown');
  }

  testClient('defaults to mobile mode with rotation button visible', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final trigger = findDropdownTrigger();
    expect(trigger.textContent, contains('Mobile'));
    expect(trigger.textContent, contains('smartphone'));

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    expect(content.className, contains('mode-mobile'));

    final rotateBtn = findRotateButton();
    expect(rotateBtn, isNotNull);
    expect(rotateBtn!.disabled, isFalse);
  });

  testClient('switches mode to tablet and updates CSS classes', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    await selectDropdownOption('Tablet');

    final trigger = findDropdownTrigger();
    expect(trigger.textContent, contains('Tablet'));
    expect(trigger.textContent, contains('tablet'));

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    expect(content.className, contains('mode-tablet'));

    final rotateBtn = findRotateButton();
    expect(rotateBtn, isNotNull);
    expect(rotateBtn!.disabled, isFalse);
  });

  testClient('switches mode to current screen size and removes rotation button', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    expect(findRotateButton(), isNotNull);

    await selectDropdownOption('Current screen size');

    final trigger = findDropdownTrigger();
    expect(trigger.textContent, contains('Current screen size'));
    expect(trigger.textContent, contains('devices'));

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    expect(content.className, contains('mode-current'));

    expect(findRotateButton(), isNull);
  });

  testClient('toggles orientation and resets rotation when switching mode', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    final rotateBtn = findRotateButton()!;

    // Initial mobile dimensions
    expect(content.style.getPropertyValue('--device-width'), '390px');
    expect(content.style.getPropertyValue('--device-height'), '846px');

    // Rotate to landscape
    rotateBtn.click();
    await pumpEventQueue();

    expect(content.style.getPropertyValue('--device-width'), '846px');
    expect(content.style.getPropertyValue('--device-height'), '390px');

    // Switching to tablet resets orientation back to default (portrait for tablet: 760x576)
    await selectDropdownOption('Tablet');

    expect(content.style.getPropertyValue('--device-width'), '760px');
    expect(content.style.getPropertyValue('--device-height'), '576px');
  });

  testClient('removes device CSS variables in current screen size mode', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    expect(content.style.getPropertyValue('--device-width'), '390px');

    await selectDropdownOption('Current screen size');

    expect(content.style.getPropertyValue('--device-width'), isEmpty);
    expect(content.style.getPropertyValue('--device-height'), isEmpty);
    expect(content.style.getPropertyValue('--device-scale'), isEmpty);
  });

  testClient('calculates downscaling when container is smaller than device dimensions', (tester) async {
    // 390px width device in a 200px wide container
    tester.pumpComponent(buildContainer(width: '200px', height: '500px'));
    await pumpEventQueue();

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    final scaleStr = content.style.getPropertyValue('--device-scale');
    expect(scaleStr, isNotEmpty);

    final scale = double.parse(scaleStr);
    expect(scale, lessThan(1.0));
    expect(scale, greaterThan(0.0));
  });

  testClient('disables dropdown and rotate button when preview is stopped', (tester) async {
    preview.setRunning(false);

    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final trigger = findDropdownTrigger();
    expect(trigger.className, contains('disabled'));
    expect(trigger.getAttribute('disabled'), 'true');

    // Clicking trigger does not open menu
    trigger.click();
    await pumpEventQueue();
    expect(web.document.querySelector('.device-dropdown-menu'), isNull);

    final rotateBtn = findRotateButton()!;
    expect(rotateBtn.disabled, isTrue);

    final content = web.document.querySelector('.preview-content') as web.HTMLElement;
    expect(content.className, contains('status-stopped'));
  });

  testClient('mounts and unmounts cleanly without errors', (tester) async {
    final showContainer = ValueNotifier(true);

    tester.pumpComponent(
      ListenableBuilder(
        listenable: showContainer,
        builder: (context) => showContainer.value ? buildContainer() : const Component.fragment([]),
      ),
    );
    await pumpEventQueue();

    expect(web.document.querySelector('.preview-container'), isNotNull);

    showContainer.value = false;
    await pumpEventQueue();

    expect(web.document.querySelector('.preview-container'), isNull);
  });
}
