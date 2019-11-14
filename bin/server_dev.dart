// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A dev-time only server; see `bin/server.dart` for the GAE server.
library services.bin;

import 'dart:async';

import 'package:dart_services/services_dev.dart' as services_dev;
import 'package:dart_services/src/sdk_manager.dart';

Future<void> main(List<String> args) async {
  await SdkManager.sdk.init();
  await SdkManager.flutterSdk.init();

  services_dev.main(args);
}
