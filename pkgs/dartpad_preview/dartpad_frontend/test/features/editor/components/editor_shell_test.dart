// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/components/editor_shell.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

/// Minimal [EditorTab] implementation for testing [EditorShell] rendering.
final class _FakeTab extends EditorTab<Component> {
  _FakeTab(super.path);

  int buildCount = 0;

  @override
  Component build() {
    buildCount++;
    return div(id: 'editor-$path', [Component.text(path)]);
  }
}

final class _FakeFileTree extends StatelessComponent {
  const _FakeFileTree();

  @override
  Component build(BuildContext context) {
    final panel = SplitPanel.of(context);
    if (panel?.isPanelCollapsed ?? false) {
      return aside(classes: 'file-tree-rail', [
        button(
          classes: 'file-tree-rail-button',
          attributes: const {
            'title': 'Show file tree',
            'aria-label': 'Show file tree',
          },
          onClick: panel?.expand,
          [const Component.text('expand')],
        ),
      ]);
    }
    return aside(classes: 'file-tree', [
      div(id: 'file-tree', [
        const Component.text('tree'),
        button(
          classes: 'file-tree-collapse-button',
          attributes: const {
            'title': 'Hide file tree',
            'aria-label': 'Hide file tree',
          },
          onClick: panel?.collapse,
          [const Component.text('collapse')],
        ),
      ]),
    ]);
  }
}

final class _FakeBottomPanel extends StatelessComponent {
  const _FakeBottomPanel();

  @override
  Component build(BuildContext context) {
    final panel = SplitPanel.of(context);
    final isCollapsed = panel?.isPanelCollapsed ?? false;
    return div(
      id: 'fake-bottom',
      classes: isCollapsed ? 'collapsed' : 'expanded',
      [
        button(
          id: 'fake-bottom-expand',
          onClick: panel?.expand,
          [const Component.text('expand')],
        ),
      ],
    );
  }
}

/// Helper that creates an [EditorShell] with sensible defaults.
EditorShell _createShell(
  ClientTester tester, {
  List<EditorTab<Component>>? openTabs,
  String activeFile = 'main.dart',
  bool isEmbedMode = false,
  SplitState? fileTreeState,
  Component? fileTree,
  Component? bottomPanel,
  PanelLayoutController? panels,
}) {
  final tabs = openTabs ?? [_FakeTab('main.dart')];
  if (panels == null) {
    panels = PanelLayoutController(isEmbedMode: isEmbedMode);
    if (fileTreeState != null) {
      panels.updateFileTree(fileTreeState);
    }
    final ownedPanels = panels;
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      ownedPanels.dispose();
    });
  }
  return EditorShell(
    openTabs: tabs,
    activeFile: activeFile,
    fileTree: fileTree ?? const _FakeFileTree(),
    editorOverlay: const div(id: 'editor-overlay', []),
    onSwitchFile: (_) {},
    onCloseFile: (_, {bool discardChanges = false}) => true,
    bottomPanel: bottomPanel ?? const div(id: 'bottom', [Component.text('bottom')]),
    panelController: panels,
  );
}

void main() {
  testClient('navigation visibility updates without rebuilding editor content', (tester) async {
    final panels = PanelLayoutController(isEmbedMode: true);
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      panels.dispose();
    });
    final tab = _FakeTab('main.dart');
    tester.pumpComponent(_createShell(tester, panels: panels, openTabs: [tab]));
    final initialBuildCount = tab.buildCount;
    expect(initialBuildCount, greaterThan(0));
    expect(web.document.querySelector('.editor-tab-bar'), isNull);
    expect(web.document.querySelector('.editor-breadcrumbs'), isNull);

    panels.applyInitialDefaults(previewRatio: 0.7, showEditorNavigation: true);
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-tab-bar'), isNotNull);
    expect(web.document.querySelector('.editor-breadcrumbs'), isNotNull);
    expect(tab.buildCount, initialBuildCount);

    panels.applyInitialDefaults(previewRatio: 0.7);
    await pumpEventQueue();
    expect(web.document.querySelector('.editor-tab-bar'), isNull);
    expect(web.document.querySelector('.editor-breadcrumbs'), isNull);
    expect(tab.buildCount, initialBuildCount);
  });

  testClient('panel updates preserve editor content without rebuilding it', (tester) async {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(() async {
      tester.binding.detachRootComponent();
      await pumpEventQueue();
      panels.dispose();
    });
    final tab = _FakeTab('main.dart');
    tester.pumpComponent(
      _createShell(tester, panels: panels, openTabs: [tab], bottomPanel: const _FakeBottomPanel()),
    );
    final initialBuildCount = tab.buildCount;
    expect(initialBuildCount, greaterThan(0));
    final editor = web.document.getElementById('editor-main.dart');
    expect(editor, isNotNull);

    panels.updatePreview(const RightCollapsed(0.6));
    await pumpEventQueue();
    expect(tab.buildCount, initialBuildCount);

    panels.updateFileTree(const LeftCollapsed(220));
    await pumpEventQueue();
    expect(web.document.querySelector('.file-tree-rail'), isNotNull);
    expect(tab.buildCount, initialBuildCount);

    panels.collapseBottomPanel();
    await pumpEventQueue();
    expect(web.document.querySelector('#fake-bottom.collapsed'), isNotNull);
    expect(tab.buildCount, initialBuildCount);

    panels.applyInitialDefaults(previewRatio: 0.7);
    await pumpEventQueue();
    expect(web.document.querySelector('.file-tree'), isNotNull);
    expect(web.document.querySelector('#fake-bottom.expanded'), isNotNull);
    expect(tab.buildCount, initialBuildCount);
    expect(web.document.getElementById('editor-main.dart')!.isSameNode(editor), isTrue);
  });

  group('EditorShell – standard mode', () {
    testClient('renders file tree pane and editor host', (tester) {
      tester.pumpComponent(_createShell(tester));

      expect(web.document.querySelector('.editor-shell'), isNotNull);
      expect(web.document.querySelector('.file-tree'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNotNull);
      expect(web.document.querySelector('#file-tree'), isNotNull);
    });

    testClient('does not render collapsed rail in standard mode', (tester) {
      tester.pumpComponent(_createShell(tester));

      expect(web.document.querySelector('.file-tree-rail'), isNull);
    });

    testClient('renders without open tabs', (tester) {
      tester.pumpComponent(_createShell(tester, openTabs: null));

      expect(web.document.querySelector('.editor-shell'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNotNull);
    });

    testClient('renders editor overlay', (tester) {
      tester.pumpComponent(_createShell(tester));

      expect(web.document.querySelector('#editor-overlay'), isNotNull);
    });

    testClient('renders editor breadcrumbs for active file', (tester) {
      tester.pumpComponent(_createShell(tester, activeFile: 'lib/main.dart'));

      expect(web.document.querySelector('.editor-breadcrumbs'), isNotNull);
      expect(web.document.querySelector('.editor-breadcrumb-folder')?.textContent, 'lib');
      expect(web.document.querySelector('.editor-breadcrumb-file')?.textContent, contains('main.dart'));
    });

    testClient('renders bottom panel', (tester) {
      tester.pumpComponent(_createShell(tester));

      expect(web.document.querySelector('#bottom'), isNotNull);
    });

    testClient('starts with expanded bottom panel in standard mode', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: false, bottomPanel: const _FakeBottomPanel()));

      final bottom = web.document.querySelector('#fake-bottom') as web.HTMLElement?;
      expect(bottom, isNotNull);
      expect(bottom!.classList.contains('expanded'), isTrue);
    });
  });

  group('EditorShell – embed mode', () {
    testClient('hides file navigation by default while keeping the editor', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true));

      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect((web.document.querySelector('.file-tree')! as web.HTMLElement).style.display, 'none');
      expect(web.document.querySelector('.editor-tab-bar'), isNull);
      expect(web.document.querySelector('.editor-breadcrumbs'), isNull);
      expect(web.document.querySelector('#editor-main\\.dart'), isNotNull);
    });

    testClient('collapsed rail has expand button with correct aria-label', (
      tester,
    ) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      final button = web.document.querySelector('.file-tree-rail .file-tree-rail-button');
      expect(button, isNotNull);
      expect(button!.getAttribute('aria-label'), 'Show file tree');
      expect(button.getAttribute('title'), 'Show file tree');
    });

    testClient('editor host is still rendered when collapsed', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      expect(web.document.querySelector('.editor-host'), isNotNull);
    });

    testClient('clicking expand button shows file tree', (
      tester,
    ) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      // Initially collapsed – rail visible, pane not.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree'), isNull);

      // Click expand button.
      final expandButton =
          web.document.querySelector('.file-tree-rail .file-tree-rail-button')! as web.HTMLButtonElement;
      expandButton.click();
      await pumpEventQueue();

      // Now expanded – pane visible, rail gone.
      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect(web.document.querySelector('.file-tree'), isNotNull);
      expect(web.document.querySelector('#file-tree'), isNotNull);
    });

    testClient('expanded view has collapse button with correct aria-label', (
      tester,
    ) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      // Expand first.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      final collapseButton = web.document.querySelector('.file-tree-collapse-button');
      expect(collapseButton, isNotNull);
      expect(collapseButton!.getAttribute('aria-label'), 'Hide file tree');
      expect(collapseButton.getAttribute('title'), 'Hide file tree');
    });

    testClient('clicking collapse button returns to rail', (tester) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      // Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.file-tree'), isNotNull);

      // Collapse.
      (web.document.querySelector('.file-tree-collapse-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      // Back to collapsed state.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree'), isNull);
    });

    testClient('toggle cycle: collapse → expand → collapse', (tester) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      // Initially collapsed.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);

      // 1. Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect(web.document.querySelector('.file-tree'), isNotNull);

      // 2. Collapse.
      (web.document.querySelector('.file-tree-collapse-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree'), isNull);

      // 3. Expand again.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect(web.document.querySelector('.file-tree'), isNotNull);
    });

    testClient('file tree content is visible when expanded', (tester) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      expect(web.document.querySelector('#file-tree'), isNotNull);
      expect(web.document.querySelector('#file-tree')!.textContent, contains('tree'));
    });

    testClient('editor host remains through toggle cycles', (tester) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, fileTreeState: const LeftCollapsed(200)));

      expect(web.document.querySelector('.editor-host'), isNotNull);

      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.editor-host'), isNotNull);

      (web.document.querySelector('.file-tree-collapse-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.editor-host'), isNotNull);
    });

    testClient('starts with collapsed bottom panel in embed mode', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, bottomPanel: const _FakeBottomPanel()));

      final bottom = web.document.querySelector('#fake-bottom') as web.HTMLElement?;
      expect(bottom, isNotNull);
      expect(bottom!.classList.contains('collapsed'), isTrue);
    });

    testClient('expanding collapsed bottom panel updates its state', (tester) async {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true, bottomPanel: const _FakeBottomPanel()));

      var bottom = web.document.querySelector('#fake-bottom') as web.HTMLElement?;
      expect(bottom!.classList.contains('collapsed'), isTrue);

      final expandBtn = web.document.querySelector('#fake-bottom-expand') as web.HTMLButtonElement;
      expandBtn.click();
      await pumpEventQueue();

      bottom = web.document.querySelector('#fake-bottom') as web.HTMLElement?;
      expect(bottom!.classList.contains('expanded'), isTrue);
    });
  });

  group('EditorShell – isEmbedMode=false vs true comparison', () {
    testClient('standard mode shows file tree pane directly', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: false));

      expect(web.document.querySelector('.file-tree'), isNotNull);
      expect(web.document.querySelector('.file-tree-rail'), isNull);
    });

    testClient('embed mode does not show file tree pane initially', (tester) {
      tester.pumpComponent(_createShell(tester, isEmbedMode: true));

      expect((web.document.querySelector('.file-tree')! as web.HTMLElement).style.display, 'none');
      expect(web.document.querySelector('.file-tree-rail'), isNull);
    });
  });
}
