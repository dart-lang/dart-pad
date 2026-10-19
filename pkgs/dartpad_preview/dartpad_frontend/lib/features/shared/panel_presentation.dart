// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Presentation of a panel that does not need a draggable split.
enum PanelPresentation {
  /// Show the panel content.
  expanded,

  /// Omit the content while retaining the panel's collapsed presentation.
  collapsed,

  /// Render nothing. Only the owner can reveal the panel.
  hidden,
}
