// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/bottom_panel/bottom_panel_state.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:dartpad_frontend/features/shared/panel_presentation.dart';
import 'package:test/test.dart';

void main() {
  for (final embed in [false, true]) {
    test('defaults and workspace resets retain existing behavior, embed=$embed', () {
      final panels = PanelLayoutController(isEmbedMode: embed);
      addTearDown(panels.dispose);
      expect(panels.preview, const Split(0.7));
      expect(panels.fileTree, embed ? const LeftCollapsed(200) : const Split(200));
      expect(panels.bottom.isExpanded, !embed);
      expect(panels.bottom.selectedTab, BottomPanelTab.problems);
      expect(panels.bottom.editorFraction, 0.75);
      expect(panels.appBar, embed ? PanelPresentation.hidden : PanelPresentation.expanded);
      expect(panels.statusBar, embed ? PanelPresentation.hidden : PanelPresentation.expanded);

      panels.openBottomPanel(BottomPanelTab.console);
      panels.updateFileTree(const Split(240));
      panels.updatePreview(const RightCollapsed(0.6));
      panels.updateAppBar(PanelPresentation.collapsed);
      panels.updateStatusBar(PanelPresentation.collapsed);
      panels.reset(previewRatio: 0.95);
      expect(panels.preview, const Split(0.95));
      expect(panels.fileTree, embed ? const LeftCollapsed(200) : const Split(200));
      expect(panels.bottom.isExpanded, !embed);
      expect(panels.bottom.selectedTab, BottomPanelTab.problems);
      expect(panels.appBar, embed ? PanelPresentation.hidden : PanelPresentation.expanded);
      expect(panels.statusBar, embed ? PanelPresentation.hidden : PanelPresentation.expanded);
    });
  }

  test('bar presentation changes are independent and notify only on changes', () {
    final panels = PanelLayoutController(isEmbedMode: false);
    addTearDown(panels.dispose);
    final changes = <(PanelPresentation, PanelPresentation)>[];
    panels.addListener(() => changes.add((panels.appBar, panels.statusBar)));

    panels.updateAppBar(PanelPresentation.collapsed);
    panels.updateAppBar(PanelPresentation.collapsed);
    panels.updateStatusBar(PanelPresentation.hidden);
    panels.updateStatusBar(PanelPresentation.hidden);
    panels.updateAppBar(PanelPresentation.hidden);
    panels.updateStatusBar(PanelPresentation.collapsed);
    panels.updateAppBar(PanelPresentation.expanded);
    panels.updateStatusBar(PanelPresentation.expanded);

    expect(changes, [
      (PanelPresentation.collapsed, PanelPresentation.expanded),
      (PanelPresentation.collapsed, PanelPresentation.hidden),
      (PanelPresentation.hidden, PanelPresentation.hidden),
      (PanelPresentation.hidden, PanelPresentation.collapsed),
      (PanelPresentation.expanded, PanelPresentation.collapsed),
      (PanelPresentation.expanded, PanelPresentation.expanded),
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
    panels.addListener(() => changes.add(panels.bottom));

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
