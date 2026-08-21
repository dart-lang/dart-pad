// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:jaspr/jaspr.dart';

/// Waits until both the worker workspace and the loaded project's initial file
/// are ready for use.
Future<({TProject project, TWorkspace workspace})> waitForWorkspaceUsable<TWorkspace, TProject>({
  required Future<TWorkspace> workspaceReady,
  required Future<TProject> projectReady,
}) async {
  final workspace = await workspaceReady;
  final project = await projectReady;
  return (workspace: workspace, project: project);
}

/// Runs [dispose] after the frame that replaces a keyed workspace subtree.
///
/// Call this after scheduling the generation change so Jaspr can unmount the
/// old subtree before its session-owned notifiers are disposed.
void disposeAfterWorkspaceUnmount(
  BuildContext context,
  Future<void> Function() dispose,
) {
  context.binding.addPostFrameCallback(() {
    unawaited(dispose());
  });
}
