// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';

/// Initial workspace splits before any user interaction.
///
/// Embeds keep the file tree rail and both bottom tabs accessible. Preview starts
/// expanded in both modes; the legacy `split` URL option can override its ratio.
abstract final class PanelDefaults {
  static const previewRatio = 0.7;
  static const editorRatio = 0.75;
  static const fileTreeWidth = 200.0;

  static const standalone = (
    preview: Split(previewRatio),
    fileTree: Split(fileTreeWidth),
    bottom: BottomPanelExpanded(BottomPanelTab.problems, editorFraction: editorRatio),
  );

  static const embed = (
    preview: Split(previewRatio),
    fileTree: LeftCollapsed(fileTreeWidth),
    bottom: BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: editorRatio),
  );
}
