// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../shared/app_event_bus.dart';

/// Stub class of SandboxVmServiceManager used during server-side compilation
/// where Flutter/DevTools web dependencies are not available.
class SandboxVmServiceManager {
  SandboxVmServiceManager(AppEventBus events);
  void dispose() {}
}
