// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import '../app_event_bus.dart';
import 'log_event.dart';

/// Requests that the workspace bottom panel switch to the Console tab.
final class OpenConsoleEvent extends AppEvent {
  const OpenConsoleEvent({this.reveal});

  /// The log whose first line is scrolled to the top of the console.
  ///
  /// Dispatch the log before this event so the console has received it.
  /// When `null`, the console keeps following new output at the bottom.
  /// Otherwise, following stops until the user scrolls back to the bottom.
  final LogEvent? reveal;
}
