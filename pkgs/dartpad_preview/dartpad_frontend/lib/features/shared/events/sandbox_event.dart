// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../../preview/models/preview_sandbox.dart';
import '../app_event_bus.dart';

/// Fired when the preview sandbox has been created or destroyed.
final class SandboxChangedEvent extends AppEvent {
  const SandboxChangedEvent(this.sandbox, {required this.isFlutterApp});

  /// The current sandbox, or null if it has been destroyed.
  final PreviewSandbox? sandbox;

  /// Whether the sandbox is running a Flutter application.
  final bool isFlutterApp;
}

final class RequestSandboxEvent extends AsyncEvent<SandboxChangedEvent> {
  RequestSandboxEvent();
}
