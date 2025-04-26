// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/headers.dart';
import 'package:shelf/shelf.dart';

class RequestContext {
  final bool loggingOn;

  RequestContext({required this.loggingOn});
}

extension RequestExtension on Request {
  RequestContext get ctx {
    return RequestContext(
      loggingOn: DartPadRequestHeaders.fromJson(headers).loggingOn,
    );
  }
}
