// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../app_event_bus.dart';

/// Requests a transient error message in the editor.
final class ErrorToastEvent extends AppEvent {
  const ErrorToastEvent(this.message);

  final String message;
}
