// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../bottom_panel/bottom_panel_state.dart';
import 'components/split_panel.dart';
import 'panel_presentation_state.dart';

/// The initial panel presentation and layout before user interaction.
typedef PanelLayoutState = ({
  PanelPresentationState appBar,
  PanelPresentationState statusBar,
  SplitState preview,
  SplitState fileTree,
  BottomPanelState bottom,
  PanelPresentationState editorNavigation,
});
