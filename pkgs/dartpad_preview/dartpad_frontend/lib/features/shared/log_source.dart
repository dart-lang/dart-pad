// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Identifies where a console message originated.
enum LogSource {
  /// Output produced by DartPad itself or one of its tools.
  system,

  /// Output produced by the running application.
  app,
}
