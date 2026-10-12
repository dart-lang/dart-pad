// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:test/test.dart';

void main() {
  PanelConfiguration parse(String query) => PanelConfiguration.fromUri(Uri.parse(query));

  test('standalone panels start expanded', () {
    final configuration = parse('');
    for (final panel in WorkspacePanel.values) {
      expect(configuration[panel], PanelPresentation.expanded);
    }
  });

  test('embed defaults retain preview and access to bottom panels', () {
    final configuration = parse('?embed=true');
    expect(configuration[WorkspacePanel.preview], PanelPresentation.expanded);
    expect(configuration[WorkspacePanel.bottomPanels], PanelPresentation.collapsed);
    for (final panel in [
      WorkspacePanel.tabs,
      WorkspacePanel.fileTree,
      WorkspacePanel.appBar,
      WorkspacePanel.statusBar,
    ]) {
      expect(configuration[panel], PanelPresentation.hidden);
    }
  });

  for (final plus in ['+', '%2B', '%2b']) {
    test('literal and encoded plus work in lists and repeated parameters: $plus', () {
      final configuration = parse('?embed=true&panels=${plus}tabs,-preview&panels=${plus}file_tree');
      expect(configuration[WorkspacePanel.tabs], PanelPresentation.expanded);
      expect(configuration[WorkspacePanel.fileTree], PanelPresentation.expanded);
      expect(configuration[WorkspacePanel.preview], PanelPresentation.hidden);
    });
  }

  test('minus collapses standalone groups except tabs and never selects the editor', () {
    final configuration = parse(
      '?panels=${WorkspacePanel.values.map((panel) => '-${panel.queryName}').join(',')},-editor',
    );
    for (final panel in WorkspacePanel.values) {
      expect(
        configuration[panel],
        panel == WorkspacePanel.tabs ? PanelPresentation.expanded : PanelPresentation.collapsed,
      );
    }
    expect(WorkspacePanel.values.any((panel) => panel.queryName == 'editor'), isFalse);
  });

  test('embed bottom panels collapse rather than hide', () {
    expect(parse('?embed=true&panels=-bottom_panels')[WorkspacePanel.bottomPanels], PanelPresentation.collapsed);
    expect(parse('?embed=true&panels=+bottom_panels')[WorkspacePanel.bottomPanels], PanelPresentation.expanded);
  });

  test('last hint wins and unsupported or malformed hints are ignored', () {
    final configuration = parse('?embed=true&panels=+tabs,-tabs,+unknown,preview,,&panels=%2Btabs,-editor');
    expect(configuration[WorkspacePanel.tabs], PanelPresentation.expanded);
    expect(configuration[WorkspacePanel.preview], PanelPresentation.expanded);
    expect(configuration[WorkspacePanel.fileTree], PanelPresentation.hidden);
  });

  test('multiple distinct explicit files infer tabs, explicit hints override inference', () {
    expect(parse('?embed=true&file=a.dart&file=b.dart')[WorkspacePanel.tabs], PanelPresentation.expanded);
    expect(parse('?embed=true&file=a.dart&file=a.dart')[WorkspacePanel.tabs], PanelPresentation.hidden);
    expect(parse('?embed=true&file=a.dart&file=b.dart&panels=-tabs')[WorkspacePanel.tabs], PanelPresentation.hidden);
  });

  test('panel toggles and resizing retain previous split sizes', () {
    final layout = PanelLayoutController(parse('?embed=true&panels=-preview'));
    addTearDown(layout.dispose);
    expect(layout.splitState(.preview, initialValue: 0.7), const RightHidden(0.7));
    layout.toggle(.preview);
    layout.updateSplit(.preview, const Split(0.6));
    layout.toggle(.preview);
    expect(layout.splitState(.preview, initialValue: 0.7), const RightCollapsed(0.6));
    layout.toggle(.preview);
    expect(layout.splitState(.preview, initialValue: 0.7), const Split(0.6));
    layout.updateSplit(.fileTree, const LeftCollapsed(225));
    layout.toggle(.fileTree);
    expect(layout.splitState(.fileTree, initialValue: 200, isLeft: true), const Split(225));
  });
}
