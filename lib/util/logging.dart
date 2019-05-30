// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:html';
import 'package:logging/logging.dart';

/// Prints [LogRecord] using to the javascript console using the corresponding
/// log levels.
void logToJsConsole(LogRecord record) {
  if (record.level >= Level.SEVERE) {
    window.console.error(record.toString());
  } else if (record.level >= Level.WARNING) {
    window.console.warn(record.toString());
  } else if (record.level >= Level.INFO) {
    window.console.info(record.toString());
  } else {
    window.console.log(record.toString());
  }
}
