// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import '../startup/query_parameters.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_layout_state.dart';
import 'panel_presentation_state.dart';

/// Initial layout hints, not constraints on subsequent user actions.
final class PanelHints {
  const PanelHints.none() : _expansionHints = const {};

  /// Applies validated URL hints to the contextual panel defaults.
  const PanelHints(this._expansionHints);

  /// The last hint for each panel, ordered by where that hint appeared in the URL.
  /// This order determines which explicitly expanded bottom tab is selected.
  final Map<WorkspacePanel, bool> _expansionHints;

  PanelLayoutState resolve({required bool isEmbedMode, bool? showEditorNavigation, double? previewRatio}) {
    final defaults = panel_defaults.resolveInitialPanelLayout(
      isEmbedMode: isEmbedMode,
      showEditorNavigation: showEditorNavigation,
      initialPreviewRatio: previewRatio,
    );
    final negativePresentation = isEmbedMode ? PanelPresentationState.hidden : PanelPresentationState.collapsed;
    PanelPresentationState resolvePresentation(WorkspacePanel panel, PanelPresentationState fallback) =>
        switch (_expansionHints[panel]) {
          true => PanelPresentationState.expanded,
          false => negativePresentation,
          null => fallback,
        };
    final preview = switch (_expansionHints[WorkspacePanel.preview]) {
      true => Split(defaults.preview.value),
      false when isEmbedMode => RightHidden(defaults.preview.value),
      false => RightCollapsed(defaults.preview.value),
      null => defaults.preview,
    };
    final fileTree = switch (_expansionHints[WorkspacePanel.fileTree]) {
      true => Split(defaults.fileTree.value),
      false when isEmbedMode => LeftHidden(defaults.fileTree.value),
      false => LeftCollapsed(defaults.fileTree.value),
      null => defaults.fileTree,
    };
    final defaultBottomPresentation = defaults.bottom.isExpanded
        ? PanelPresentationState.expanded
        : PanelPresentationState.collapsed;
    final consolePresentation = resolvePresentation(WorkspacePanel.console, defaultBottomPresentation);
    final problemsPresentation = resolvePresentation(WorkspacePanel.problems, defaultBottomPresentation);
    final bottomPresentation = _resolveBottomPresentation(consolePresentation, problemsPresentation);
    final selectedTab = _resolveBottomTab(
      consolePresentation: consolePresentation,
      problemsPresentation: problemsPresentation,
      defaultTab: defaults.bottom.selectedTab,
    );
    final editorFraction = defaults.bottom.editorFraction;
    return (
      appBar: resolvePresentation(WorkspacePanel.appBar, defaults.appBar),
      statusBar: resolvePresentation(WorkspacePanel.statusBar, defaults.statusBar),
      preview: preview,
      fileTree: fileTree,
      bottom: switch (bottomPresentation) {
        PanelPresentationState.expanded => BottomPanelExpanded(selectedTab, editorFraction: editorFraction),
        PanelPresentationState.collapsed => BottomPanelCollapsed(selectedTab, editorFraction: editorFraction),
        PanelPresentationState.hidden => BottomPanelHidden(selectedTab, editorFraction: editorFraction),
      },
      editorNavigation: resolvePresentation(WorkspacePanel.tabs, defaults.editorNavigation),
    );
  }

  PanelPresentationState _resolveBottomPresentation(
    PanelPresentationState consolePresentation,
    PanelPresentationState problemsPresentation,
  ) {
    // Both tabs share one area. Keep it as visible as either tab requests.
    if (consolePresentation == PanelPresentationState.expanded ||
        problemsPresentation == PanelPresentationState.expanded) {
      return PanelPresentationState.expanded;
    }
    if (consolePresentation == PanelPresentationState.collapsed ||
        problemsPresentation == PanelPresentationState.collapsed) {
      return PanelPresentationState.collapsed;
    }
    return PanelPresentationState.hidden;
  }

  BottomPanelTab _resolveBottomTab({
    required PanelPresentationState consolePresentation,
    required PanelPresentationState problemsPresentation,
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
    if (consolePresentation != problemsPresentation) {
      final bottomPresentation = _resolveBottomPresentation(consolePresentation, problemsPresentation);
      return consolePresentation == bottomPresentation ? BottomPanelTab.console : BottomPanelTab.problems;
    }
    return defaultTab;
  }
}
