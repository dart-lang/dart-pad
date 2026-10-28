// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_defaults.dart' as panel_defaults;
import 'panel_layout_state.dart';
import 'panel_presentation_state.dart';
import 'workspace_mode.dart';

/// Initial layout hints, not constraints on subsequent user actions.
///
/// Null retains the contextual default. False collapses or hides the panel,
/// depending on the workspace mode and the panel's available presentations.
final class PanelHints {
  const PanelHints.none() : this();

  const PanelHints({
    this.console,
    this.problems,
    this.preview,
    this.editorNavigation,
    this.fileTree,
    this.appBar,
    this.statusBar,
    this.preferredBottomTab,
  });

  final bool? console;
  final bool? problems;
  final bool? preview;
  final bool? editorNavigation;
  final bool? fileTree;
  final bool? appBar;
  final bool? statusBar;

  /// Explicit bottom-tab preference after conflicting hints have been resolved.
  /// Null leaves selection to the contextual layout defaults.
  final BottomPanelTab? preferredBottomTab;

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
    final preview = switch (this.preview) {
      true => Split(defaults.preview.value),
      false => RightHidden(defaults.preview.value),
      null => defaults.preview,
    };
    final fileTree = switch (this.fileTree) {
      true => Split(defaults.fileTree.value),
      false => LeftHidden(defaults.fileTree.value),
      null => defaults.fileTree,
    };
    final appBar = switch (this.appBar) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.appBar,
    };
    final statusBar = switch (this.statusBar) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.statusBar,
    };
    final bottom = _resolveBottomPanel(defaults.bottom, mode: WorkspaceMode.embed);
    final editorNavigation = switch (this.editorNavigation) {
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
    final preview = switch (this.preview) {
      true => Split(defaults.preview.value),
      false => RightCollapsed(defaults.preview.value),
      null => defaults.preview,
    };
    final fileTree = switch (this.fileTree) {
      true => Split(defaults.fileTree.value),
      false => LeftCollapsed(defaults.fileTree.value),
      null => defaults.fileTree,
    };
    final appBar = switch (this.appBar) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.appBar,
    };
    final statusBar = switch (this.statusBar) {
      true => PanelPresentationState.expanded,
      false => PanelPresentationState.hidden,
      null => defaults.statusBar,
    };
    final bottom = _resolveBottomPanel(defaults.bottom, mode: WorkspaceMode.standalone);
    final editorNavigation = switch (this.editorNavigation) {
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
    final consoleState = switch (console) {
      true => expanded,
      false => nonExpanded,
      null => defaults,
    };
    final problemsState = switch (problems) {
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
    if (preferredBottomTab case final tab?) {
      return tab;
    }
    // Without an explicit selection, prefer the more visible tab.
    if (consoleState != problemsState) {
      final bottomState = _moreVisibleBottomPanel(consoleState, problemsState);
      return consoleState == bottomState ? BottomPanelTab.console : BottomPanelTab.problems;
    }
    return defaultTab;
  }
}
