// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_services;

import 'dart:async';

import 'package:http/browser_client.dart';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../dartservices_client/v1.dart';

// For indexing deps.
abstract class DartServices {}

class DartServicesModule extends Module {
  DartServicesModule();

  Future init() {
    var client = new BrowserClient();
    deps[DartServices] = new DartservicesApi(client);
    return new Future.value();
  }
}
