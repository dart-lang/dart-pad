// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

/// A single rendered line in the console.
final class ConsoleEntry {
  const ConsoleEntry({required this.message, required this.level});

  final String message;
  final Level level;
}
