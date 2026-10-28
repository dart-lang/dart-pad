// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import '../startup/query_parameters.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_layout_state.dart';
import 'panel_presentation_state.dart';
import 'workspace_mode.dart';

/// Initial layout hints, not constraints on subsequent user actions.
final class PanelHints {
  const PanelHints.none() : _expansionHints = const {};

  /// Applies validated URL hints to the contextual panel defaults.
  const PanelHints(this._expansionHints);

  /// The last hint for each panel, ordered by where that hint appeared in the URL.
  /// This order determines which explicitly expanded bottom tab is selected.
  final Map<WorkspacePanel, bool> _expansionHints;

  PanelLayoutState resolve({required WorkspaceMode mode, bool? showEditorNavigation, double? previewRatio}) {
    final defaults = panel_defaults.resolveInitialPanelLayout(
      mode: mode,
      showEditorNavigation: showEditorNavigation,
      initialPreviewRatio: previewRatio,
    );
    return switch (mode) {
      WorkspaceMode.standalone => _buildStandaloneLayout(defaults),
      WorkspaceMode.embed => _buildEmbedLayout(defaults),
    };
  }

  PanelLayoutState _buildEmbedLayout(PanelLayoutState defaults) {
    final preview = switch (_expansionHints[WorkspacePanel.preview]) {
      true => Split(defaults.preview.value),
      false => RightHidden(defaults.preview.value),
      null => defaults.preview,
    };
    final fileTree = switch (_expansionHints[WorkspacePanel.fileTree]) {
      true => Split(defaults.fileTree.value),
      false => LeftHidden(defaults.fileTree.value),
      null => defaults.fileTree,
    };
    final appBar = switch (_expansionHints[WorkspacePanel.appBar]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.appBar,
    };
    final statusBar = switch (_expansionHints[WorkspacePanel.statusBar]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.statusBar,
    };
    final bottom = _resolveBottomPanel(defaults.bottom, mode: WorkspaceMode.embed);
    final editorNavigation = switch (_expansionHints[WorkspacePanel.tabs]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.editorNavigation,
    };
    final PanelLayoutState layout = (
      appBar: appBar,
      statusBar: statusBar,
      preview: preview,
      fileTree: fileTree,
      bottom: bottom,
      editorNavigation: editorNavigation,
    );
    return layout;
  }

  PanelLayoutState _buildStandaloneLayout(PanelLayoutState defaults) {
    final preview = switch (_expansionHints[WorkspacePanel.preview]) {
      true => Split(defaults.preview.value),
      false => RightCollapsed(defaults.preview.value),
      null => defaults.preview,
    };
    final fileTree = switch (_expansionHints[WorkspacePanel.fileTree]) {
      true => Split(defaults.fileTree.value),
      false => LeftCollapsed(defaults.fileTree.value),
      null => defaults.fileTree,
    };
    final appBar = switch (_expansionHints[WorkspacePanel.appBar]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.appBar,
    };
    final statusBar = switch (_expansionHints[WorkspacePanel.statusBar]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.statusBar,
    };
    final bottom = _resolveBottomPanel(defaults.bottom, mode: WorkspaceMode.standalone);
    final editorNavigation = switch (_expansionHints[WorkspacePanel.tabs]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.editorNavigation,
    };
    final PanelLayoutState layout = (
      appBar: appBar,
      statusBar: statusBar,
      preview: preview,
      fileTree: fileTree,
      bottom: bottom,
      editorNavigation: editorNavigation,
    );
    return layout;
  }

  BottomPanelState _resolveBottomPanel(
    BottomPanelState defaults, {
    required WorkspaceMode mode,
  }) {
    final editorFraction = defaults.editorFraction;
    final expanded = BottomPanelExpanded(defaults.selectedTab, editorFraction: editorFraction);
    final nonExpanded = switch (mode) {
      WorkspaceMode.standalone => BottomPanelCollapsed(defaults.selectedTab, editorFraction: editorFraction),
      WorkspaceMode.embed => BottomPanelHidden(defaults.selectedTab, editorFraction: editorFraction),
    };
    final consoleState = switch (_expansionHints[WorkspacePanel.console]) {
      true => expanded,
      false => nonExpanded,
      null => defaults,
    };
    final problemsState = switch (_expansionHints[WorkspacePanel.problems]) {
      true => expanded,
      false => nonExpanded,
      null => defaults,
    };
    final bottomState = _moreVisibleBottomPanel(consoleState, problemsState);
    final selectedTab = _resolveBottomTab(
      consoleState: consoleState,
      problemsState: problemsState,
      defaultTab: defaults.selectedTab,
    );
    return switch (bottomState) {
      BottomPanelExpanded() => BottomPanelExpanded(selectedTab, editorFraction: editorFraction),
      BottomPanelCollapsed() => BottomPanelCollapsed(selectedTab, editorFraction: editorFraction),
      BottomPanelHidden() => BottomPanelHidden(selectedTab, editorFraction: editorFraction),
    };
  }

  /// Both tabs share one area. Keep it as visible as either tab requests.
  BottomPanelState _moreVisibleBottomPanel(BottomPanelState consoleState, BottomPanelState problemsState) =>
      switch ((consoleState, problemsState)) {
        (BottomPanelExpanded(), _) => consoleState,
        (_, BottomPanelExpanded()) => problemsState,
        (BottomPanelCollapsed(), _) => consoleState,
        (_, BottomPanelCollapsed()) => problemsState,
        _ => consoleState,
      };

  BottomPanelTab _resolveBottomTab({
    required BottomPanelState consoleState,
    required BottomPanelState problemsState,
    required BottomPanelTab defaultTab,
  }) {
    // Prefer the last positive bottom-tab hint that has not been superseded.
    for (final hint in _expansionHints.entries.toList().reversed) {
      if (!hint.value) {
        continue;
      }
      switch (hint.key) {
        case WorkspacePanel.console:
          return BottomPanelTab.console;
        case WorkspacePanel.problems:
          return BottomPanelTab.problems;
        default:
          break;
      }
    }
    // Without an explicit selection, prefer the more visible tab.
    if (consoleState != problemsState) {
      final bottomState = _moreVisibleBottomPanel(consoleState, problemsState);
      return consoleState == bottomState ? BottomPanelTab.console : BottomPanelTab.problems;
    }
    return defaultTab;
  }
}
