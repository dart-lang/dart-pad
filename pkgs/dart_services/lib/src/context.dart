// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_shared/headers.dart';
import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';

class DartPadRequestContext {
  final bool enableLogging;

  @visibleForTesting
  DartPadRequestContext({this.enableLogging = true});

  factory DartPadRequestContext.fromRequest(Request request) {
    return DartPadRequestContext(
      enableLogging: DartPadRequestHeaders.fromJson(
        request.headers,
      ).enableLogging,
    );
  }
}
