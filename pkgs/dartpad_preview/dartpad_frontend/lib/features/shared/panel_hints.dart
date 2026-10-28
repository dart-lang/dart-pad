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
    if (isEmbedMode) {
      return _buildEmbedLayout(defaults);
    }
    return _buildStandaloneLayout(defaults);
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
    final bottom = _resolveBottomPanel(defaults.bottom, negativePresentation: PanelPresentationState.hidden);
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
      false => PanelPresentationState.collapsed,
      null => defaults.appBar,
    };
    final statusBar = switch (_expansionHints[WorkspacePanel.statusBar]) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.collapsed,
      null => defaults.statusBar,
    };
    final bottom = _resolveBottomPanel(defaults.bottom, negativePresentation: PanelPresentationState.collapsed);
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
    required PanelPresentationState negativePresentation,
  }) {
    final defaultBottomPresentation = defaults.isExpanded
        ? PanelPresentationState.expanded
        : PanelPresentationState.collapsed;
    final consolePresentation = switch (_expansionHints[WorkspacePanel.console]) {
      true => PanelPresentationState.expanded,
      false => negativePresentation,
      null => defaultBottomPresentation,
    };
    final problemsPresentation = switch (_expansionHints[WorkspacePanel.problems]) {
      true => PanelPresentationState.expanded,
      false => negativePresentation,
      null => defaultBottomPresentation,
    };
    final bottomPresentation = _resolveBottomPresentation(consolePresentation, problemsPresentation);
    final selectedTab = _resolveBottomTab(
      consolePresentation: consolePresentation,
      problemsPresentation: problemsPresentation,
      defaultTab: defaults.selectedTab,
    );
    final editorFraction = defaults.editorFraction;
    return switch (bottomPresentation) {
      PanelPresentationState.expanded => BottomPanelExpanded(selectedTab, editorFraction: editorFraction),
      PanelPresentationState.collapsed => BottomPanelCollapsed(selectedTab, editorFraction: editorFraction),
      PanelPresentationState.hidden => BottomPanelHidden(selectedTab, editorFraction: editorFraction),
    };
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
