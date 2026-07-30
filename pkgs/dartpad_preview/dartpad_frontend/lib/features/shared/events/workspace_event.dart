// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../workspace/data/workspace_repository.dart';
import '../app_event_bus.dart';

/// Fired when the [WorkspaceRepository] has been initialized.
final class WorkspaceInitializedEvent extends AppEvent {
  const WorkspaceInitializedEvent(this.workspace);

  final WorkspaceRepository workspace;
}
