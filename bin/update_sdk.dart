// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// Update the sdk in `dart-sdk/` if necessary.
import 'dart:async';

import 'package:dart_services/src/sdk_manager.dart';
import 'package:logging/logging.dart';

Logger _logger = new Logger('update_sdk');

Future main() async {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((LogRecord record) {
    print(record);
    if (record.stackTrace != null) print(record.stackTrace);
  });

  DownloadingSdk sdk = new DownloadingSdk();
  await sdk.init();

  _logger.info('Dart SDK ${sdk.version} available at ${sdk.sdkPath}');
}
