// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Initial panel states for standalone and embed mode.
///
/// Embeds hide file navigation and keep both bottom tabs accessible. Preview starts
/// expanded in both modes; the legacy `split` URL option can override its ratio.
library;

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_layout_state.dart';
import 'panel_presentation_state.dart';

const previewRatio = 0.7;
const editorRatio = 0.75;
const fileTreeWidth = 200.0;

/// Resolve initial panel states with an optional editor-navigation override.
/// Without an override, tabs and breadcrumbs are visible outside embeds.
PanelLayoutState resolveInitialPanelLayout({
  required bool isEmbedMode,
  bool? showEditorNavigation,
  double? initialPreviewRatio,
}) {
  final preview = Split(initialPreviewRatio ?? previewRatio);
  final editorNavigation = (showEditorNavigation ?? !isEmbedMode)
      ? PanelPresentationState.expanded
      : PanelPresentationState.hidden;
  if (isEmbedMode) {
    return (
      appBar: PanelPresentationState.hidden,
      statusBar: PanelPresentationState.hidden,
      preview: preview,
      fileTree: const LeftHidden(fileTreeWidth),
      bottom: const BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: editorRatio),
      editorNavigation: editorNavigation,
    );
  }
  return (
    appBar: PanelPresentationState.expanded,
    statusBar: PanelPresentationState.expanded,
    preview: preview,
    fileTree: const Split(fileTreeWidth),
    bottom: const BottomPanelExpanded(BottomPanelTab.problems, editorFraction: editorRatio),
    editorNavigation: editorNavigation,
  );
}
