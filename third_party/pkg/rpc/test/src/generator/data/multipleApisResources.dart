// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library multipleapis_resources;

import 'package:rpc/src/annotations.dart';
import 'multipleApisMessages.dart';

class ApiTwoResource {
  ApiTwoResource();

  @ApiMethod(path: 'apitwo/resource/{name}')
  ApiTwoResponse apiTwoGetWithParams(String name) {
    return new ApiTwoResponse()..result = 'Hello ${name}!';
  }
}
