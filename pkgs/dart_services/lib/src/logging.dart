// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:logging/logging.dart';

import 'context.dart';

const bool verboseLogging = false;

final _wsRegex = RegExp(r' \s+');

void emitLogsToStdout() {
  Logger.root.onRecord.listen((LogRecord record) {
    if (verboseLogging || record.level >= Level.INFO) {
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
  late final Logger _logger;

  DartPadLogger(String name) {
    _logger = Logger(name);
  }

  void fine(String s, DartPadRequestContext ctx) {
    if (ctx.enableLogging) {
      _logger.fine(s);
    }
  }

  void warning(String s, DartPadRequestContext ctx) {
    if (ctx.enableLogging) {
      _logger.warning(s);
    }
  }

  void info(String s, DartPadRequestContext ctx) {
    if (ctx.enableLogging) {
      _logger.info(s);
    }
  }

  /// Logs a generic info message that doesn't relate to a request.
  void genericInfo(String s) {
    _logger.info(s);
  }

  void severe(
    String s,
    DartPadRequestContext ctx, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (ctx.enableLogging) {
      _logger.severe(s, error, stackTrace);
    }
  }

  /// Logs a generic info message that doesn't relate to a request.
  void genericSevere(String s, {Object? error, StackTrace? stackTrace}) {
    _logger.severe(s, error, stackTrace);
  }
}
