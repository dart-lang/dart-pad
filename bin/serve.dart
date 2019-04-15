// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(createCorsHeadersMiddleware())
      .addMiddleware(logRequests())
      .addHandler(createStaticHandler('build', defaultDocument: 'index.html'));

  final server = await io.serve(handler, 'localhost', 8000)
    ..autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

/// Middleware which adds [CORS headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS)
/// to shelf responses. Also handles preflight (OPTIONS) requests.
Middleware createCorsHeadersMiddleware({Map<String, String> corsHeaders}) {
  // By default allow access from everywhere.
  corsHeaders ??= <String, String>{'Access-Control-Allow-Origin': '*'};

  // Handle preflight (OPTIONS) requests by just adding headers and an empty
  // response.
  Response handleOptionsRequest(Request request) {
    if (request.method == 'OPTIONS') {
      return Response.ok(null, headers: corsHeaders);
    } else {
      return null;
    }
  }

  Response addCorsHeaders(Response response) =>
      response.change(headers: corsHeaders);

  return createMiddleware(
      requestHandler: handleOptionsRequest, responseHandler: addCorsHeaders);
}
