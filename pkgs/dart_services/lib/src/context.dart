// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:math';

import 'package:dartpad_shared/headers.dart';
import 'package:shelf/shelf.dart';

final _random = Random();
const int _maxInt32 = -1 >>> 1;

class RequestContext {
  final bool enableLogging;
  final String requestId = _random.nextInt(_maxInt32).toString();

  RequestContext({required this.enableLogging});
}

extension RequestExtension on Request {
  RequestContext get ctx {
    return RequestContext(
      enableLogging: DartPadRequestHeaders.fromJson(headers).enableLogging,
    );
  }
}
