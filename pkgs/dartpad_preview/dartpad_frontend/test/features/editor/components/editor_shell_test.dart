// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/editor/components/editor_shell.dart';
import 'package:jaspr/dom.dart' hide path;
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:web/web.dart' as web;

/// Minimal [EditorTab] implementation for testing [EditorShell] rendering.
final class _FakeTab extends EditorTab<Component> {
  _FakeTab(super.path);

  @override
  Component build() => div(id: 'editor-$path', [Component.text(path)]);
}

/// Helper that creates an [EditorShell] with sensible defaults.
EditorShell _createShell({
  List<EditorTab<Component>>? openTabs,
  String activeFile = 'main.dart',
  bool isEmbedMode = false,
}) {
  final tabs = openTabs ?? [_FakeTab('main.dart')];
  return EditorShell(
    openTabs: tabs,
    activeFile: activeFile,
    fileTree: const div(id: 'file-tree', [Component.text('tree')]),
    editorOverlay: const div(id: 'editor-overlay', []),
    onSwitchFile: (_) {},
    onCloseFile: (_, {bool discardChanges = false}) => true,
    bottomPanel: const div(id: 'bottom', [Component.text('bottom')]),
    isEmbedMode: isEmbedMode,
  );
}

void main() {
  group('EditorShell – standard mode', () {
    testClient('renders file tree pane and editor host', (tester) {
      tester.pumpComponent(_createShell());

      expect(web.document.querySelector('.editor-shell'), isNotNull);
      expect(web.document.querySelector('.file-tree-pane'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNotNull);
      expect(web.document.querySelector('#file-tree'), isNotNull);
    });

    testClient('does not render embed-mode elements', (tester) {
      tester.pumpComponent(_createShell());

      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNull);
    });

    testClient('renders without open tabs', (tester) {
      tester.pumpComponent(_createShell(openTabs: null));

      expect(web.document.querySelector('.editor-shell'), isNotNull);
      expect(web.document.querySelector('.editor-host'), isNotNull);
    });

    testClient('renders editor overlay', (tester) {
      tester.pumpComponent(_createShell());

      expect(web.document.querySelector('#editor-overlay'), isNotNull);
    });

    testClient('renders bottom panel', (tester) {
      tester.pumpComponent(_createShell());

      expect(web.document.querySelector('#bottom'), isNotNull);
    });
  });

  group('EditorShell – embed mode', () {
    testClient('starts with collapsed file tree rail', (tester) {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Collapsed: rail is visible, full file-tree pane is not.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree-pane'), isNull);
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNull);
    });

    testClient('collapsed rail has expand button with correct aria-label', (
      tester,
    ) {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      final button = web.document.querySelector('.file-tree-rail .file-tree-rail-button');
      expect(button, isNotNull);
      expect(button!.getAttribute('aria-label'), 'Show file tree');
      expect(button.getAttribute('title'), 'Show file tree');
    });

    testClient('editor host is still rendered when collapsed', (tester) {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      expect(web.document.querySelector('.editor-host'), isNotNull);
    });

    testClient('clicking expand button shows file tree with collapse bar', (
      tester,
    ) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Initially collapsed – rail visible, pane not.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree-pane'), isNull);

      // Click expand button.
      final expandButton =
          web.document.querySelector('.file-tree-rail .file-tree-rail-button')! as web.HTMLButtonElement;
      expandButton.click();
      await pumpEventQueue();

      // Now expanded – pane and collapse bar visible, rail gone.
      expect(web.document.querySelector('.file-tree-rail'), isNull);
      expect(web.document.querySelector('.file-tree-pane'), isNotNull);
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNotNull);
      expect(web.document.querySelector('#file-tree'), isNotNull);
    });

    testClient('expanded view has collapse button with correct aria-label', (
      tester,
    ) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Expand first.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      final collapseButton = web.document.querySelector('.file-tree-collapse-bar .file-tree-rail-button');
      expect(collapseButton, isNotNull);
      expect(collapseButton!.getAttribute('aria-label'), 'Hide file tree');
      expect(collapseButton.getAttribute('title'), 'Hide file tree');
    });

    testClient('clicking collapse button returns to rail', (tester) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.file-tree-pane'), isNotNull);

      // Collapse.
      (web.document.querySelector('.file-tree-collapse-bar .file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      // Back to collapsed state.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree-pane'), isNull);
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNull);
    });

    testClient('toggle cycle: collapse → expand → collapse', (tester) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // State 1: collapsed (initial).
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);

      // Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      // State 2: expanded.
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNotNull);
      expect(web.document.querySelector('.file-tree-rail'), isNull);

      // Collapse.
      (web.document.querySelector('.file-tree-collapse-bar .file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      // State 3: collapsed again.
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
      expect(web.document.querySelector('.file-tree-collapse-bar'), isNull);
    });

    testClient('file tree content is visible when expanded', (tester) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Collapsed: file tree is not rendered in the pane.
      expect(web.document.querySelector('.file-tree-pane #file-tree'), isNull);

      // Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();

      // File tree content is now visible inside the pane.
      expect(web.document.querySelector('.file-tree-pane #file-tree'), isNotNull);
    });

    testClient('editor host remains through toggle cycles', (tester) async {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      // Collapsed.
      expect(web.document.querySelector('.editor-host'), isNotNull);

      // Expand.
      (web.document.querySelector('.file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.editor-host'), isNotNull);

      // Collapse again.
      (web.document.querySelector('.file-tree-collapse-bar .file-tree-rail-button')! as web.HTMLButtonElement).click();
      await pumpEventQueue();
      expect(web.document.querySelector('.editor-host'), isNotNull);
    });
  });

  group('EditorShell – isEmbedMode=false vs true comparison', () {
    testClient('standard mode shows file tree pane directly', (tester) {
      tester.pumpComponent(_createShell(isEmbedMode: false));

      expect(web.document.querySelector('.file-tree-pane'), isNotNull);
      expect(web.document.querySelector('.file-tree-rail'), isNull);
    });

    testClient('embed mode does not show file tree pane initially', (tester) {
      tester.pumpComponent(_createShell(isEmbedMode: true));

      expect(web.document.querySelector('.file-tree-pane'), isNull);
      expect(web.document.querySelector('.file-tree-rail'), isNotNull);
    });
  });
}
