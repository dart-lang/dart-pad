// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Visibility of a panel without a collapsed presentation.
enum PanelPresentationState {
  /// Show the panel content.
  expanded,

  /// Render nothing. Only the owner can reveal the panel.
  hidden,
}
