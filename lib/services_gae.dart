// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_gae;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart' as rpc;

import 'src/common.dart';
import 'src/common_server.dart';
import 'src/dartpad_support_server.dart';
import 'src/sharded_counter.dart' as counter;

const String _API = '/api';

final Logger _logger = Logger('gae_server');

void main(List<String> args) {
  int gaePort = 8080;
  if (args.isNotEmpty) gaePort = int.parse(args[0]);

  String sdk = sdkPath;

  if (sdk == null) {
    throw 'No Dart SDK is available; set the DART_SDK env var.';
  }

  GaeServer server = GaeServer(sdk);

  // Change the log level to get more or less detailed logging.
  ae.useLoggingPackageAdaptor();
  server.start(gaePort);
}

class GaeServer {
  final String sdkPath;

  bool discoveryEnabled;
  rpc.ApiServer apiServer;
  CommonServer commonServer;
  FileRelayServer fileRelayServer;

  GaeServer(this.sdkPath) {
    hierarchicalLoggingEnabled = true;
    _logger.level = Level.ALL;

    discoveryEnabled = false;
    fileRelayServer = FileRelayServer();
    commonServer = CommonServer(
        sdkPath, GaeServerContainer(), InmemoryCache(), GaeCounter());
    // Enabled pretty printing of returned json for debuggability.
    apiServer = rpc.ApiServer(apiPrefix: _API, prettyPrint: true)
      ..addApi(commonServer)
      ..addApi(fileRelayServer);
  }

  Future start([int gaePort = 8080]) async {
    await commonServer.init();
    return ae.runAppEngine(requestHandler, port: gaePort);
  }

  void requestHandler(io.HttpRequest request) {
    request.response.headers
        .add('Access-Control-Allow-Methods', 'POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept');

    // Explicitly handle an OPTIONS requests.
    if (request.method == 'OPTIONS') {
      var requestedMethod =
          request.headers.value('access-control-request-method');
      var statusCode;
      if (requestedMethod != null && requestedMethod.toUpperCase() == 'POST') {
        statusCode = io.HttpStatus.ok;
      } else {
        statusCode = io.HttpStatus.badRequest;
      }
      request.response
        ..statusCode = statusCode
        ..close();
      return;
    }

    if (request.uri.path.startsWith(_API)) {
      if (!discoveryEnabled) {
        apiServer.enableDiscoveryApi();
        discoveryEnabled = true;
      }
      // NOTE: We could read in the request body here and parse it similar to
      // the _parseRequest method to determine content-type and dispatch to e.g.
      // a plain text handler if we want to support that.
      var apiRequest = rpc.HttpApiRequest.fromHttpRequest(request);

      // Dartpad sends data as plain text, we need to promote this to
      // application/json to ensure that the rpc library processes it correctly
      apiRequest.headers['content-type'] = 'application/json; charset=utf-8';
      apiServer
          .handleHttpApiRequest(apiRequest)
          .then((rpc.HttpApiResponse apiResponse) {
        return rpc.sendApiResponse(apiResponse, request.response);
      }).catchError((e) {
        // This should only happen in the case where there is a bug in the rpc
        // package. Otherwise it always returns an HttpApiResponse.
        _logger.warning('Failed with error: $e when trying to call '
            'method at \'${request.uri.path}\'.');
        request.response
          ..statusCode = io.HttpStatus.internalServerError
          ..close();
      });
    } else {
      request.response
        ..statusCode = io.HttpStatus.internalServerError
        ..close();
    }
  }
}

class GaeServerContainer implements ServerContainer {
  @override
  String get version => io.Platform.version;
}

class GaeCounter implements PersistentCounter {
  @override
  Future<int> getTotal(String name) {
    return counter.Counter.getTotal(name);
  }

  @override
  Future increment(String name, {int increment = 1}) {
    return counter.Counter.increment(name, increment: increment);
  }
}
