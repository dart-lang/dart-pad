// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_gae;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart';
import 'package:memcache/memcache.dart';
import 'package:rpc/rpc.dart';
import 'src/common_server.dart';

Logging get logging => context.services.logging;
Memcache get memcache => context.services.memcache;

void main() {
  GaeServer server = new GaeServer('/usr/lib/dart');
  server.start();
}

class GaeServer {
  final String sdkPath;

  bool discoveryEnabled;
  ApiServer apiServer;
  CommonServer commonServer;

  GaeServer(this.sdkPath) {
    discoveryEnabled = false;
    commonServer = new CommonServer(sdkPath, new GaeLogger(), new GaeCache());
    // Enabled pretty printing of returned json for debuggability.
    apiServer = new ApiServer(prettyPrint: true)..addApi(commonServer);
  }

  Future start() => runAppEngine(requestHandler);

  void requestHandler(io.HttpRequest request) {
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Credentials', 'true');
    request.response.headers.add('Access-Control-Allow-Methods',
        'POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept');
    // Explicitly handle an OPTIONS requests.
    if (request.method == 'OPTIONS') {
      var requestedMethod =
          request.headers.value('access-control-request-method');
      var statusCode;
      if (requestedMethod != null && requestedMethod.toUpperCase() == 'POST') {
        statusCode = io.HttpStatus.OK;
      } else {
        statusCode = io.HttpStatus.BAD_REQUEST;
      }
      request.response..statusCode = statusCode
                      ..close();
      return;
    }
    var requestPath = request.uri.path;
    if (request.uri.path.startsWith('/api')) {
      // Strip off the leading '/api' prefix.
      requestPath = requestPath.substring('/api'.length);

      if (!discoveryEnabled) {
        apiServer.enableDiscoveryApi(request.requestedUri.origin, '/api');
        discoveryEnabled = true;
      }
      // NOTE: We could read in the request body here and parse it similar to
      // the _parseRequest method to determine content-type and dispatch to e.g.
      // a plain text handler if we want to support that.
      var apiRequest = new HttpApiRequest(request.method, requestPath,
                                          request.uri.queryParameters,
                                          request.headers.contentType.toString(),
                                          request);
      apiServer.handleHttpRequest(apiRequest)
          .then((HttpApiResponse apiResponse) =>
              _sendResponse(request, apiResponse))
          .catchError((e) {
            // This should only happen in the case where there is a bug in the
            // rpc package. Otherwise it always returns an HttpApiResponse.
            commonServer.log.warn('Failed with error: $e when trying to call'
                'method at \'$requestPath\'.');
            request.response..statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR
                            ..close();
          });
    } else {
      request.response..statusCode = io.HttpStatus.INTERNAL_SERVER_ERROR
                       ..close();
    }
  }

  void _sendResponse(io.HttpRequest request, HttpApiResponse response) {
    request.response.statusCode = response.status;
    request.response.headers.add(io.HttpHeaders.CONTENT_TYPE,
                                 response.headers[io.HttpHeaders.CONTENT_TYPE]);
    response.body.pipe(request.response);
  }
}

class GaeLogger implements ServerLogger {
  Logging get _logging => context.services.logging;

  void info(String message) => _logging.info(message);
  void warn(String message) => _logging.warning(message);
  void error(String message) => _logging.error(message);
}

class GaeCache implements ServerCache {
  Memcache get _memcache => context.services.memcache;

  Future<String> get(String key) => _memcache.get(key);

  Future set(String key, String value, {Duration expiration}) {
    return _memcache.set(key, value, expiration: expiration);
  }

  Future remove(String key) => _memcache.remove(key);
}
