// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';


final _wsRegex = RegExp(r' \s+');

void emitLogsToStdout() {
  Logger.root.onRecord.listen((LogRecord record) {
    if (record.level >= Level.INFO) {
      final String stackTrace;
      if (record.stackTrace case final recordStackTrace?) {
        final lines = recordStackTrace
            .toString()
            .split('\n')
            .take(5)
            .join(' ')
            .replaceAll(_wsRegex, ' ');
        stackTrace = ' $lines';
      } else {
        stackTrace = '';
      }

      print(
        '[${record.level.name.toLowerCase()}] '
        '${record.message}'
        '$stackTrace',
      );
    }
  });
}

class DartPadLogger {
  final Logger logger;

  DartPadLogger(String name) : logger = Logger(name);

  void fine(String s) {
    logger.fine(s);
  }

  void info(String s) {
    logger.info(s);
  }

  void warning(String s, [Object? error, StackTrace? stackTrace]) {
    logger.warning(s, error, stackTrace);
  }

  void severe(String s, {Object? error, StackTrace? stackTrace}) {
    logger.severe(s, error, stackTrace);
  }
}
