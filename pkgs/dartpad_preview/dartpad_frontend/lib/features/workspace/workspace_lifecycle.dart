// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

/// Runs [dispose] after the frame that replaces a keyed workspace subtree.
///
/// Call this after scheduling the session replacement so Jaspr can unmount the
/// old subtree before its session-owned notifiers are disposed.
void disposeAfterWorkspaceUnmount(
  BuildContext context,
  Future<void> Function() dispose,
) {
  context.binding.addPostFrameCallback(() {
    unawaited(dispose());
  });
}
