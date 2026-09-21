// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';

/// Immutable tab identity, safe to retain after its editor has been disposed.
final class TabDescriptor {
  const TabDescriptor({required this.path, required this.origin});

  /// A workspace-relative path, or an absolute URI for a system tab.
  final String path;
  final EditorTabOrigin origin;
}
