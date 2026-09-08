// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_frontend/features/bottom_panel/models/console_entry.dart';
import 'package:dartpad_frontend/features/preview/components/runtime_button.dart';
import 'package:dartpad_frontend/features/preview/models/preview_state.dart';
import 'package:dartpad_frontend/features/preview/view/preview_container.dart';
import 'package:dartpad_frontend/features/preview/view_models/preview_view_model.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
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
  final List<ConsoleEntry> appLogs = [];

  void setRunning({required bool value}) {
    isRunning = value;
    canStart = !value;
    canRestart = value;
    canHotReload = value;
    canStop = value;
    state = value ? PreviewRunning('lib/main.dart') : PreviewInitial();
    notifyListeners();
  }

  @override
  Future<void> runCode(String activeFile) async {}

  @override
  Future<void> hotReloadCode() async {}

  @override
  Future<void> stopCode() async {}

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
    style.textContent =
        '''
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
      ${PreviewContainer.styles.map((rule) => rule.toCss()).join('\n')}
      ${RuntimeButton.styles.map((rule) => rule.toCss()).join('\n')}
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
      key: ValueKey('container-$width-$height-${customPreview?.isFlutter ?? preview.isFlutter}'),
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

  List<web.HTMLButtonElement> findRuntimeButtons() {
    final list = <web.HTMLButtonElement>[];
    final buttons = web.document.querySelectorAll('.preview-controls .runtime-button');
    for (var i = 0; i < buttons.length; i++) {
      list.add(buttons.item(i) as web.HTMLButtonElement);
    }
    return list;
  }

  web.HTMLButtonElement findDropdownTrigger() {
    return web.document.querySelector('.device-dropdown-trigger')! as web.HTMLButtonElement;
  }

  web.HTMLElement findDropdownLabel() {
    return web.document.querySelector('.device-dropdown-label')! as web.HTMLElement;
  }

  Future<void> selectDropdownOption(String title) async {
    final trigger = findDropdownTrigger();
    trigger.click();
    await pumpEventQueue();

    final items = web.document.querySelectorAll('.dropdown-menu-item');
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

  group('PreviewContainer – collapse button', () {
    testClient('does not render collapse button when not in a SplitPanel', (tester) {
      tester.pumpComponent(buildContainer());

      expect(web.document.querySelector('button[aria-label="Hide preview"]'), isNull);
    });

    testClient('renders collapse button when in SplitPanel', (tester) {
      tester.pumpComponent(
        SplitPanel(
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      final button = web.document.querySelector('button[aria-label="Hide preview"]') as web.HTMLButtonElement?;
      expect(button, isNotNull);
      expect(button!.getAttribute('aria-label'), 'Hide preview');
    });

    testClient('renders preview-rail and keeps container mounted when collapsed in SplitPanel', (tester) {
      tester.pumpComponent(
        SplitPanel(
          initialState: const RightCollapsed(0.7),
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);
      expect(web.document.querySelector('.preview-rail:not(.hidden)'), isNotNull);
      expect(web.document.querySelector('.preview-rail button'), isNotNull);
      expect(web.document.querySelector('.preview-toolbar.hidden'), isNotNull);
      expect(web.document.querySelector('.preview-content.collapsed'), isNotNull);
    });

    testClient('collapsing and expanding preserves containerElement in the DOM', (tester) async {
      final splitKey = GlobalStateKey<SplitPanelState>();
      tester.pumpComponent(
        SplitPanel(
          key: splitKey,
          initialState: const Split(0.7),
          canCollapseRight: true,
          left: const div([]),
          right: PreviewContainer(
            preview: preview,
            taskStatus: taskStatus,
            activeFile: 'lib/main.dart',
            onOpenConsole: () {},
          ),
        ),
      );

      final containerElement = preview.containerElement;
      expect(containerElement.isConnected, isTrue);

      // Collapse right panel
      splitKey.currentState!.collapseRight();
      await pumpEventQueue();

      expect(containerElement.isConnected, isTrue);
      expect(web.document.querySelector('.preview-container.collapsed'), isNotNull);

      // Expand right panel
      splitKey.currentState!.split();
      await pumpEventQueue();

      expect(containerElement.isConnected, isTrue);
      expect(web.document.querySelector('.preview-container:not(.collapsed)'), isNotNull);
    });
  });

  group('PreviewContainer – device mode & controls', () {
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

    testClient('switches mode to full size and removes rotation button', (tester) async {
      tester.pumpComponent(buildContainer());
      await pumpEventQueue();

      expect(findRotateButton(), isNotNull);

      await selectDropdownOption('Full size');

      final trigger = findDropdownTrigger();
      expect(trigger.textContent, contains('Full size'));
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

    testClient('removes device CSS variables in full size mode', (tester) async {
      tester.pumpComponent(buildContainer());
      await pumpEventQueue();

      final content = web.document.querySelector('.preview-content') as web.HTMLElement;
      expect(content.style.getPropertyValue('--device-width'), '390px');

      await selectDropdownOption('Full size');

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
      preview.setRunning(value: false);

      tester.pumpComponent(buildContainer());
      await pumpEventQueue();

      final trigger = findDropdownTrigger();
      expect(trigger.className, contains('disabled'));
      expect(trigger.getAttribute('disabled'), 'true');

      // Clicking trigger does not open menu
      trigger.click();
      await pumpEventQueue();
      expect(web.document.querySelector('.dropdown-menu-panel'), isNull);

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
  });

  testClient('renders runtime buttons with icons and labels', (tester) async {
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    expect(buttons, hasLength(3));

    // Running mode shows Reload first, Restart second, Stop third
    expect(buttons[0].querySelector('.runtime-button-label')?.textContent, 'Reload');
    expect(buttons[0].textContent, contains('bolt'));

    expect(buttons[1].querySelector('.runtime-button-label')?.textContent, 'Restart');
    expect(buttons[1].textContent, contains('restart_alt'));

    expect(buttons[2].querySelector('.runtime-button-label')?.textContent, 'Stop');
    expect(buttons[2].textContent, contains('stop'));
  });

  testClient('shows Start button when preview is stopped', (tester) async {
    preview.setRunning(value: false);
    tester.pumpComponent(buildContainer());
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    expect(buttons, hasLength(3));

    expect(buttons[0].querySelector('.runtime-button-label')?.textContent, 'Start');
    expect(buttons[0].textContent, contains('play_arrow'));

    expect(buttons[1].querySelector('.runtime-button-label')?.textContent, 'Restart');
    expect(buttons[1].textContent, contains('restart_alt'));

    expect(buttons[2].querySelector('.runtime-button-label')?.textContent, 'Stop');
    expect(buttons[2].textContent, contains('stop'));
  });

  testClient('hides all button and dropdown labels in narrow Flutter toolbar (< 270px)', (tester) async {
    tester.pumpComponent(buildContainer(width: '250px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    for (final btn in buttons) {
      final label = btn.querySelector('.runtime-button-label') as web.HTMLElement;
      expect(web.window.getComputedStyle(label).display, 'none');
    }
    expect(web.window.getComputedStyle(findDropdownLabel()).display, 'none');
  });

  testClient(
    'expands only the first button label while hiding dropdown label in Flutter toolbar (270px - 319px)',
    (tester) async {
      tester.pumpComponent(buildContainer(width: '280px'));
      await pumpEventQueue();

      final buttons = findRuntimeButtons();
      final firstLabel = buttons[0].querySelector('.runtime-button-label') as web.HTMLElement;
      final secondLabel = buttons[1].querySelector('.runtime-button-label') as web.HTMLElement;
      final thirdLabel = buttons[2].querySelector('.runtime-button-label') as web.HTMLElement;

      expect(web.window.getComputedStyle(firstLabel).display, isNot('none'));
      expect(web.window.getComputedStyle(secondLabel).display, 'none');
      expect(web.window.getComputedStyle(thirdLabel).display, 'none');
      expect(web.window.getComputedStyle(findDropdownLabel()).display, 'none');
    },
  );

  testClient('expands dropdown label and first button in medium-wide Flutter toolbar (320px - 409px)', (tester) async {
    tester.pumpComponent(buildContainer(width: '340px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    final firstLabel = buttons[0].querySelector('.runtime-button-label') as web.HTMLElement;
    final secondLabel = buttons[1].querySelector('.runtime-button-label') as web.HTMLElement;
    final thirdLabel = buttons[2].querySelector('.runtime-button-label') as web.HTMLElement;

    expect(web.window.getComputedStyle(firstLabel).display, isNot('none'));
    expect(web.window.getComputedStyle(secondLabel).display, 'none');
    expect(web.window.getComputedStyle(thirdLabel).display, 'none');
    expect(web.window.getComputedStyle(findDropdownLabel()).display, isNot('none'));
  });

  testClient('expands all button labels and dropdown label in wide Flutter toolbar (>= 410px)', (tester) async {
    tester.pumpComponent(buildContainer(width: '420px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    for (final btn in buttons) {
      final label = btn.querySelector('.runtime-button-label') as web.HTMLElement;
      expect(web.window.getComputedStyle(label).display, isNot('none'));
    }
    expect(web.window.getComputedStyle(findDropdownLabel()).display, isNot('none'));
  });

  testClient('hides all button labels in narrow Dart toolbar (< 180px)', (tester) async {
    final dartPreview = FakePreviewViewModel()..isFlutter = false;
    tester.pumpComponent(buildContainer(customPreview: dartPreview, width: '140px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    for (final btn in buttons) {
      final label = btn.querySelector('.runtime-button-label') as web.HTMLElement;
      expect(web.window.getComputedStyle(label).display, 'none');
    }
    dartPreview.dispose();
  });

  testClient('expands only the first button in medium Dart toolbar (180px - 269px)', (tester) async {
    final dartPreview = FakePreviewViewModel()..isFlutter = false;
    tester.pumpComponent(buildContainer(customPreview: dartPreview, width: '200px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    final firstLabel = buttons[0].querySelector('.runtime-button-label') as web.HTMLElement;
    final secondLabel = buttons[1].querySelector('.runtime-button-label') as web.HTMLElement;
    final thirdLabel = buttons[2].querySelector('.runtime-button-label') as web.HTMLElement;

    expect(web.window.getComputedStyle(firstLabel).display, isNot('none'));
    expect(web.window.getComputedStyle(secondLabel).display, 'none');
    expect(web.window.getComputedStyle(thirdLabel).display, 'none');
    dartPreview.dispose();
  });

  testClient('expands all buttons in wide Dart toolbar (>= 270px)', (tester) async {
    final dartPreview = FakePreviewViewModel()..isFlutter = false;
    tester.pumpComponent(buildContainer(customPreview: dartPreview, width: '300px'));
    await pumpEventQueue();

    final buttons = findRuntimeButtons();
    for (final btn in buttons) {
      final label = btn.querySelector('.runtime-button-label') as web.HTMLElement;
      expect(web.window.getComputedStyle(label).display, isNot('none'));
    }
    dartPreview.dispose();
  });
}
