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
      .addMiddleware(_canonicalHeadersMiddleware)
      .addHandler(createStaticHandler('build', defaultDocument: 'index.html'));

  final server = await io.serve(handler, 'localhost', 8000)
    ..autoCompress = true;

  print('Serving at http://${server.address.host}:${server.port}');
}

const _canonicalHost = 'dartpad.dev';

// Ensures that alternate hosts for this site (dartpad.dartlang.org) hint to
// search engines where the "real" domain is.
//
// See https://en.wikipedia.org/wiki/Canonical_link_element
Handler _canonicalHeadersMiddleware(Handler innerHandler) => (request) async {
      var response = await innerHandler(request);

      if (
          // Only set the header if there is a mismatch
          request.requestedUri.host != _canonicalHost &&
              // Only set the header for HTML content.
              response.headers['content-type'] == 'text/html') {
        final newUri = request.requestedUri.replace(host: _canonicalHost);

        response = response.change(
          headers: {
            'Link': '<$newUri>; rel="canonical"',
          },
        );
      }

      return response;
    };

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
