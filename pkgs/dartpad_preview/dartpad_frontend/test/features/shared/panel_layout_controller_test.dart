// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/bottom_panel/bottom_panel_state.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:dartpad_frontend/features/shared/panel_presentation_state.dart';
import 'package:test/test.dart';

void main() {
  test('bottom split listenable follows the shared state and preserves tab selection', () {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(panels.dispose);
    final split = panels.bottomSplitListenable;
    final changes = <SplitState>[];
    void onChange() => changes.add(split.value);
    split.addListener(onChange);
    expect(panels.bottomSplitListenable, same(split));
    expect(split.value, const Split(0.75));

    panels.openBottomPanel(BottomPanelTab.console);
    panels.updateBottomSplit(const RightCollapsed(0.6));
    expect(split.value, const RightCollapsed(0.6));
    expect(panels.bottom.selectedTab, BottomPanelTab.console);
    panels.updateBottomSplit(const Split(0.6));
    expect(split.value, const Split(0.6));
    expect(panels.bottom.selectedTab, BottomPanelTab.console);
    expect(changes, const [Split(0.75), RightCollapsed(0.6), Split(0.6)]);

    split.removeListener(onChange);
    panels.collapseBottomPanel();
    expect(split.value, const RightCollapsed(0.6));
    expect(changes, hasLength(3));
  });

  test('each panel notifies only its own listeners and skips unchanged values', () {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(panels.dispose);
    final changes = <String>[];
    panels.previewListenable.addListener(() => changes.add('preview'));
    panels.fileTreeListenable.addListener(() => changes.add('fileTree'));
    panels.bottomListenable.addListener(() => changes.add('bottom'));
    panels.appBarListenable.addListener(() => changes.add('appBar'));
    panels.statusBarListenable.addListener(() => changes.add('statusBar'));

    panels.updatePreview(const RightCollapsed(0.6));
    panels.updatePreview(const RightCollapsed(0.6));
    expect(changes, ['preview']);

    changes.clear();
    panels.updateFileTree(const LeftCollapsed(220));
    panels.updateFileTree(const LeftCollapsed(220));
    expect(changes, ['fileTree']);

    changes.clear();
    panels.openBottomPanel(BottomPanelTab.console);
    panels.openBottomPanel(BottomPanelTab.console);
    expect(changes, ['bottom']);

    changes.clear();
    panels.expandPreview();
    panels.expandPreview();
    expect(changes, ['preview']);

    changes.clear();
    panels.applyInitialDefaults(previewRatio: 0.6);
    expect(changes, ['fileTree', 'bottom']);
    expect(panels.previewListenable.value, panels.preview);
    expect(panels.fileTreeListenable.value, panels.fileTree);
    expect(panels.bottomListenable.value, panels.bottom);

    changes.clear();
    panels.applyInitialDefaults(previewRatio: 0.6);
    expect(changes, isEmpty);
    panels.applyInitialDefaults(previewRatio: 0.7);
    expect(changes, ['preview']);
  });

  for (final embed in [false, true]) {
    test('initial defaults apply the presentation for embed=$embed', () {
      final panels = PanelLayoutController(isEmbedMode: embed);
      addTearDown(panels.dispose);
      expect(panels.preview, const Split(0.7));
      expect(panels.fileTree, embed ? const LeftHidden(200) : const Split(200));
      expect(panels.showEditorTabs, !embed);
      expect(panels.showBreadcrumbs, !embed);
      expect(panels.bottom.isExpanded, !embed);
      expect(panels.bottom.selectedTab, BottomPanelTab.problems);
      expect(panels.bottom.editorFraction, 0.75);
      expect(panels.appBar, embed ? PanelPresentationState.hidden : PanelPresentationState.expanded);
      expect(panels.statusBar, embed ? PanelPresentationState.hidden : PanelPresentationState.expanded);

      panels.openBottomPanel(BottomPanelTab.console);
      panels.updateFileTree(const Split(240));
      panels.updatePreview(const RightCollapsed(0.6));
      panels.updateAppBar(PanelPresentationState.collapsed);
      panels.updateStatusBar(PanelPresentationState.collapsed);
      panels.applyInitialDefaults(previewRatio: 0.95);
      expect(panels.preview, const Split(0.95));
      expect(panels.fileTree, embed ? const LeftHidden(200) : const Split(200));
      expect(panels.bottom.isExpanded, !embed);
      expect(panels.bottom.selectedTab, BottomPanelTab.problems);
      expect(panels.appBar, embed ? PanelPresentationState.hidden : PanelPresentationState.expanded);
      expect(panels.statusBar, embed ? PanelPresentationState.hidden : PanelPresentationState.expanded);
    });

    for (final files in [
      <String>[],
      ['main.dart'],
      ['main.dart', 'main.dart'],
      ['main.dart', 'helper.dart', 'main.dart'],
    ]) {
      test('navigation uses distinct requested files: $files, embed=$embed', () {
        final panels = PanelLayoutController(isEmbedMode: embed, files: files);
        addTearDown(panels.dispose);
        final visible = !embed || files.toSet().length > 1;
        expect(panels.showEditorTabs, visible);
        expect(panels.showBreadcrumbs, visible);
        expect(panels.fileTree, embed ? const LeftHidden(200) : const Split(200));

        panels.applyInitialDefaults(previewRatio: 0.7);
        expect(panels.showEditorTabs, !embed);
        expect(panels.showBreadcrumbs, !embed);
        panels.applyInitialDefaults(previewRatio: 0.7, files: files);
        expect(panels.showEditorTabs, visible);
        expect(panels.showBreadcrumbs, visible);
      });
    }
  }

  test('bar presentation changes are independent and notify only on changes', () {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(panels.dispose);
    final changes = <(PanelPresentationState, PanelPresentationState)>[];
    void recordChange() => changes.add((panels.appBar, panels.statusBar));
    panels.appBarListenable.addListener(recordChange);
    panels.statusBarListenable.addListener(recordChange);

    panels.updateAppBar(PanelPresentationState.collapsed);
    panels.updateAppBar(PanelPresentationState.collapsed);
    panels.updateStatusBar(PanelPresentationState.hidden);
    panels.updateStatusBar(PanelPresentationState.hidden);
    panels.updateAppBar(PanelPresentationState.hidden);
    panels.updateStatusBar(PanelPresentationState.collapsed);
    panels.updateAppBar(PanelPresentationState.expanded);
    panels.updateStatusBar(PanelPresentationState.expanded);

    expect(changes, [
      (PanelPresentationState.collapsed, PanelPresentationState.expanded),
      (PanelPresentationState.collapsed, PanelPresentationState.hidden),
      (PanelPresentationState.hidden, PanelPresentationState.hidden),
      (PanelPresentationState.hidden, PanelPresentationState.collapsed),
      (PanelPresentationState.expanded, PanelPresentationState.collapsed),
      (PanelPresentationState.expanded, PanelPresentationState.expanded),
    ]);
    expect(panels.preview, const Split(0.7));
    expect(panels.fileTree, const Split(200));
    expect(panels.bottom, const BottomPanelExpanded(BottomPanelTab.problems, editorFraction: 0.75));
  });

  test('opening a tab updates selection and expansion atomically, preserving size', () {
    final panels = PanelLayoutController(isEmbedMode: true);
    addTearDown(panels.dispose);
    panels.updateBottomSplit(const RightCollapsed(0.6));
    final changes = <BottomPanelState>[];
    panels.bottomListenable.addListener(() => changes.add(panels.bottom));

    panels.openBottomPanel(BottomPanelTab.console);
    panels.openBottomPanel(BottomPanelTab.console);
    panels.collapseBottomPanel();
    panels.updateBottomSplit(const Split(0.6));
    panels.openBottomPanel(BottomPanelTab.problems);

    expect(changes, const [
      BottomPanelExpanded(BottomPanelTab.console, editorFraction: 0.6),
      BottomPanelCollapsed(BottomPanelTab.console, editorFraction: 0.6),
      BottomPanelExpanded(BottomPanelTab.console, editorFraction: 0.6),
      BottomPanelExpanded(BottomPanelTab.problems, editorFraction: 0.6),
    ]);
  });

  test('bottom split cannot hide the tabs or collapse the editor', () {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(panels.dispose);
    final original = panels.bottom;
    for (final state in [const RightHidden(0.7), const LeftHidden(0.7), const LeftCollapsed(0.7)]) {
      expect(() => panels.updateBottomSplit(state), throwsArgumentError);
      expect(panels.bottom, original);
    }
  });

  test('preview expansion restores the resized split without changing other panels', () {
    final panels = PanelLayoutController(isEmbedMode: true);
    addTearDown(panels.dispose);
    panels.updateFileTree(const LeftCollapsed(225));
    panels.updatePreview(const RightCollapsed(0.6));
    panels.expandPreview();
    expect(panels.preview, const Split(0.6));
    expect(panels.fileTree, const LeftCollapsed(225));
    expect(panels.bottom, const BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: 0.75));
  });
}
