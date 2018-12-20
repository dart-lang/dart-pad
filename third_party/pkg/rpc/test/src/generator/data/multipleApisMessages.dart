// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library multipleapis_messages;

import 'package:rpc/src/annotations.dart';

class ApiOneResponse {
  String result;
  ApiOneResponse();
}

class ApiOneRequest {
  @ApiProperty(required: true)
  String name;

  @ApiProperty(defaultValue: 1000)
  int age;
}

class ApiTwoResponse {
  String result;
  ApiTwoResponse();
}

class ApiTwoRequest {
  String name;

  @ApiProperty(defaultValue: 2000)
  int age;
}
