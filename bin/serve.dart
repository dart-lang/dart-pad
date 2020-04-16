// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final handler = const Pipeline()
      .addMiddleware(_corsHeadersMiddleware)
      .addMiddleware(logRequests())
      .addHandler(createStaticHandler('build', defaultDocument: 'index.html'));

  final server = await io.serve(handler, 'localhost', 8000)
    ..autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

// By default allow access from everywhere.
const _corsHeaders = <String, String>{'Access-Control-Allow-Origin': '*'};

/// Middleware which adds [CORS headers](https://developer.mozilla.org/en-US/docs/Web/HTTP/Access_control_CORS)
/// to shelf responses. Also handles preflight (OPTIONS) requests.
Handler _corsHeadersMiddleware(Handler innerHandler) => (request) async {
      if (request.method == 'OPTIONS') {
        return Response.ok(null, headers: _corsHeaders);
      }

      final response = await innerHandler(request);

      return response.change(headers: _corsHeaders);
    };
