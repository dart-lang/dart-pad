// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_presentation.dart';

/// Initial panel states for standalone and embed mode.
///
/// Embeds hide file navigation and keep both bottom tabs accessible. Preview starts
/// expanded in both modes; the legacy `split` URL option can override its ratio.
abstract final class PanelDefaults {
  static const previewRatio = 0.7;
  static const editorRatio = 0.75;
  static const fileTreeWidth = 200.0;

  /// Resolve initial panel states from the project request.
  /// Explicit multi-file embeds show tabs and breadcrumbs.
  static ({
    PanelPresentation appBar,
    PanelPresentation statusBar,
    Split preview,
    SplitState fileTree,
    BottomPanelState bottom,
    bool showEditorTabs,
    bool showBreadcrumbs,
  })
  resolve({required bool isEmbedMode, Iterable<String> files = const [], double? previewRatio}) {
    final preview = Split(previewRatio ?? PanelDefaults.previewRatio);
    if (isEmbedMode) {
      final showEditorNavigation = files.toSet().length > 1;
      return (
        appBar: PanelPresentation.hidden,
        statusBar: PanelPresentation.hidden,
        preview: preview,
        fileTree: const LeftHidden(fileTreeWidth),
        bottom: const BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: editorRatio),
        showEditorTabs: showEditorNavigation,
        showBreadcrumbs: showEditorNavigation,
      );
    }
    return (
      appBar: PanelPresentation.expanded,
      statusBar: PanelPresentation.expanded,
      preview: preview,
      fileTree: const Split(fileTreeWidth),
      bottom: const BottomPanelExpanded(BottomPanelTab.problems, editorFraction: editorRatio),
      showEditorTabs: true,
      showBreadcrumbs: true,
    );
  }
}
