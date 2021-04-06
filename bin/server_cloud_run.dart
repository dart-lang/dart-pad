// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A dev-time only server; see `bin/server.dart` for the GAE server.
library services.bin;

import 'dart:async';

import 'package:dart_services/services_cloud_run.dart' as services_cloud_run;

Future<void> main(List<String> args) async {
  return services_cloud_run.main(args);
}
