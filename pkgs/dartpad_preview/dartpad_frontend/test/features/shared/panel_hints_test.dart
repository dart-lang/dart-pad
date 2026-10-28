// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/bottom_panel/bottom_panel_state.dart';
import 'package:dartpad_frontend/features/shared/components/split_panel.dart';
import 'package:dartpad_frontend/features/shared/panel_defaults.dart';
import 'package:dartpad_frontend/features/shared/panel_layout_controller.dart';
import 'package:dartpad_frontend/features/shared/panel_presentation_state.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:test/test.dart';

void main() {
  for (final embed in [false, true]) {
    final suffix = '&embed=$embed';
    test('absent and invalid hints retain contextual defaults, embed=$embed', () {
      for (final hints in [
        '',
        '&panels=',
        '&panels=console,+unknown,++tabs,-,+Preview,%252Bpreview',
        '&panels=-file_tree,-app_bar,-status_bar',
      ]) {
        final request = ProjectRequest.fromUri(Uri.parse('?file=a&file=b$suffix$hints'));
        expect(
          request.panels.resolve(isEmbedMode: embed, showEditorNavigation: true),
          resolveInitialPanelLayout(isEmbedMode: embed, showEditorNavigation: true),
        );
      }
    });

    test('all positive hints open their panels and override embed defaults, embed=$embed', () {
      final request = ProjectRequest.fromUri(
        Uri.parse('?panels=+console,+problems,+preview,+tabs,+filetree,+appbar,+statusbar&split=60$suffix'),
      );
      final state = request.panels.resolve(isEmbedMode: embed, previewRatio: request.initialSplitRatio);
      expect(state.bottom, const BottomPanelExpanded(BottomPanelTab.problems, editorFraction: 0.75));
      expect(state.preview, const Split(0.6));
      expect(state.fileTree, const Split(200));
      expect(state.editorNavigation, PanelPresentationState.expanded);
      expect(state.appBar, PanelPresentationState.expanded);
      expect(state.statusBar, PanelPresentationState.expanded);
    });

    test('negative hints always hide tabs; other panels collapse in standalone and hide in embeds, embed=$embed', () {
      final request = ProjectRequest.fromUri(
        Uri.parse('?panels=-console,-problems,-preview,-tabs,-filetree,-appbar,-statusbar&split=60$suffix'),
      );
      final state = request.panels.resolve(
        isEmbedMode: embed,
        showEditorNavigation: true,
        previewRatio: request.initialSplitRatio,
      );
      expect(
        state.bottom,
        embed
            ? const BottomPanelHidden(BottomPanelTab.problems, editorFraction: 0.75)
            : const BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: 0.75),
      );
      expect(state.preview, embed ? const RightHidden(0.6) : const RightCollapsed(0.6));
      expect(state.fileTree, embed ? const LeftHidden(200) : const LeftCollapsed(200));
      expect(state.editorNavigation, PanelPresentationState.hidden);
      expect(state.appBar, embed ? PanelPresentationState.hidden : PanelPresentationState.collapsed);
      expect(state.statusBar, embed ? PanelPresentationState.hidden : PanelPresentationState.collapsed);
    });

    for (final (hints, selected) in [
      ('+console', BottomPanelTab.console),
      ('+problems', BottomPanelTab.problems),
      ('-console,+problems', BottomPanelTab.problems),
      ('+problems,-console', BottomPanelTab.problems),
      ('-problems,+console', BottomPanelTab.console),
      ('+console,-problems', BottomPanelTab.console),
      ('+console,+problems', BottomPanelTab.problems),
      ('+problems,+console', BottomPanelTab.console),
      ('+console,+problems,+console', BottomPanelTab.console),
      ('+console,+problems,-problems', BottomPanelTab.console),
      ('+problems,+console,-console', BottomPanelTab.problems),
      ('-console,-problems,+console', BottomPanelTab.console),
    ]) {
      test('$hints selects $selected and opens the shared area, embed=$embed', () {
        final request = ProjectRequest.fromUri(Uri.parse('?panels=$hints$suffix'));
        expect(request.panels.resolve(isEmbedMode: embed).bottom, BottomPanelExpanded(selected, editorFraction: 0.75));
      });
    }

    for (final (hint, selected) in [('-console', BottomPanelTab.problems), ('-problems', BottomPanelTab.console)]) {
      test('$hint keeps the other default and both tabs accessible, embed=$embed', () {
        final request = ProjectRequest.fromUri(Uri.parse('?panels=$hint$suffix'));
        expect(
          request.panels.resolve(isEmbedMode: embed).bottom,
          embed
              ? BottomPanelCollapsed(selected, editorFraction: 0.75)
              : BottomPanelExpanded(selected, editorFraction: 0.75),
        );
      });
    }

    test('last hints win across repeated parameters, with superseded focus removed, embed=$embed', () {
      final request = ProjectRequest.fromUri(
        Uri.parse(
          '?panels=+console,+problems,-preview,+filetree,-tabs&panels=-problems,+preview,-filetree,+tabs$suffix',
        ),
      );
      final state = request.panels.resolve(isEmbedMode: embed);
      expect(state.bottom, const BottomPanelExpanded(BottomPanelTab.console, editorFraction: 0.75));
      expect(state.preview, const Split(0.7));
      expect(state.fileTree, embed ? const LeftHidden(200) : const LeftCollapsed(200));
      expect(state.editorNavigation, PanelPresentationState.expanded);
    });

    test('hints initialize shared state and do not constrain later actions, embed=$embed', () {
      final panels = PanelLayoutController(isEmbedMode: embed);
      addTearDown(panels.dispose);
      final request = ProjectRequest.fromUri(Uri.parse('?panels=-console,-problems,-preview,-tabs&split=60$suffix'));
      panels.applyInitialDefaults(previewRatio: request.initialSplitRatio, hints: request.panels);
      expect(panels.bottomSplitListenable.value, embed ? const RightHidden(0.75) : const RightCollapsed(0.75));
      panels.openBottomPanel(BottomPanelTab.console);
      panels.expandPreview();
      expect(panels.bottomSplitListenable.value, const Split(0.75));
      expect(panels.preview, const Split(0.6));
    });
  }

  test('literal and encoded plus signs survive request/history round trips', () {
    for (final query in [
      '?panels=+console,-problems,+tabs&panels=+filetree&embed=true',
      '?panels=%2Bconsole%2C-problems%2C%2Btabs&panels=%2Bfiletree&embed=true',
      '?panels=%20+console%20,%20-problems,%09+tabs%20&panels=%20+filetree%20&embed=true',
    ]) {
      final request = ProjectRequest.fromUri(Uri.parse(query));
      final restored = ProjectRequest.fromUri(Uri.parse(request.search));
      expect(request.query['panels'], ['+console,-problems,+tabs', '+filetree']);
      expect(restored.query, request.query);
      final expected = request.panels.resolve(isEmbedMode: true);
      expect(expected.bottom.selectedTab, BottomPanelTab.console);
      expect(expected.bottom.isExpanded, isTrue);
      expect(restored.panels.resolve(isEmbedMode: true), expected);
      expect(() => request.query['panels']!.add('-preview'), throwsUnsupportedError);
    }
  });
}
