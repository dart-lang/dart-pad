// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

const bool verboseLogging = false;

void emitLogsToStdout() {
  Logger.root.onRecord.listen((LogRecord record) {
    if (verboseLogging || record.level >= Level.INFO) {
      print('[${record.level.name.toLowerCase()}] ${record.message}');
      if (record.stackTrace != null) {
        print(record.stackTrace);
      }
    }
  });
}
