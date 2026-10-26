// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Initial workspace splits before any user interaction.
///
/// Embeds keep the file tree rail and both bottom tabs accessible. Preview starts
/// expanded in both modes; the legacy `split` URL option can override its ratio.
library;

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';

const previewRatio = 0.7;
const editorRatio = 0.75;
const fileTreeWidth = 200.0;

const standalone = (
  preview: Split(previewRatio),
  fileTree: Split(fileTreeWidth),
  bottom: BottomPanelExpanded(BottomPanelTab.problems, editorFraction: editorRatio),
);

const embed = (
  preview: Split(previewRatio),
  fileTree: LeftCollapsed(fileTreeWidth),
  bottom: BottomPanelCollapsed(BottomPanelTab.problems, editorFraction: editorRatio),
);
