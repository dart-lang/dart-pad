// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_gae;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:dart_services/src/sdk_manager.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart' as rpc;

import 'src/common.dart';
import 'src/common_server.dart';
import 'src/flutter_web.dart';
import 'src/server_cache.dart';

const String _API = '/api';
const String _healthCheck = '/_ah/health';
const String _readynessCheck = '/_ah/ready';

final Logger _logger = Logger('gae_server');

void main(List<String> args) {
  var gaePort = 8080;
  if (args.isNotEmpty) gaePort = int.parse(args[0]);

  final sdk = sdkPath;

  if (sdk == null) {
    throw 'No Dart SDK is available; set the DART_SDK env var.';
  }

  // Log to stdout/stderr.  AppEngine's logging package is disabled in 0.6.0
  // and AppEngine copies stdout/stderr to the dashboards.
  _logger.onRecord.listen((LogRecord rec) {
    final out = ('${rec.level.name}: ${rec.time}: ${rec.message}\n');
    if (rec.level > Level.INFO) {
      io.stderr.write(out);
    } else {
      io.stdout.write(out);
    }
  });
  log.info('''Initializing dart-services:
    port: $gaePort
    sdkPath: $sdkPath
    REDIS_SERVER_URI: ${io.Platform.environment['REDIS_SERVER_URI']}
    GAE_VERSION: ${io.Platform.environment['GAE_VERSION']}
  ''');

  final server = GaeServer(sdk, io.Platform.environment['REDIS_SERVER_URI']);
  server.start(gaePort);
}

class GaeServer {
  final String sdkPath;
  final String redisServerUri;

  bool discoveryEnabled;
  rpc.ApiServer apiServer;
  FlutterWebManager flutterWebManager;
  CommonServer commonServer;

  GaeServer(this.sdkPath, this.redisServerUri) {
    hierarchicalLoggingEnabled = true;
    recordStackTraceAtLevel = Level.SEVERE;

    _logger.level = Level.ALL;

    discoveryEnabled = false;
    flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
    commonServer = CommonServer(
        sdkPath,
        flutterWebManager,
        GaeServerContainer(),
        redisServerUri == null
            ? InMemoryCache()
            : RedisCache(
                redisServerUri, io.Platform.environment['GAE_VERSION']));
    // Enabled pretty printing of returned json for debuggability.
    apiServer = rpc.ApiServer(apiPrefix: _API, prettyPrint: true)
      ..addApi(commonServer);
  }

  Future<dynamic> start([int gaePort = 8080]) async {
    await commonServer.init();
    return ae.runAppEngine(requestHandler, port: gaePort);
  }

  Future<void> requestHandler(io.HttpRequest request) async {
    request.response.headers
        .add('Access-Control-Allow-Methods', 'POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept');

    if (request.method == 'OPTIONS') {
      await _processOptionsRequest(request);
    } else if (request.uri.path == _readynessCheck) {
      await _processReadynessRequest(request);
    } else if (request.uri.path == _healthCheck) {
      await _processHealthRequest(request);
    } else if (request.uri.path.startsWith(_API)) {
      await _processApiRequest(request);
    } else {
      await _processDefaultRequest(request);
    }
  }

  Future<void> _processOptionsRequest(io.HttpRequest request) async {
    final requestedMethod =
        request.headers.value('access-control-request-method');
    int statusCode;
    if (requestedMethod != null && requestedMethod.toUpperCase() == 'POST') {
      statusCode = io.HttpStatus.ok;
    } else {
      statusCode = io.HttpStatus.badRequest;
    }
    request.response.statusCode = statusCode;
    await request.response.close();
  }

  Future _processReadynessRequest(io.HttpRequest request) async {
    if (commonServer.running) {
      request.response.statusCode = io.HttpStatus.ok;
    } else {
      request.response.statusCode = io.HttpStatus.internalServerError;
      _logger.info('CommonServer not running - failing readiness check.');
    }

    await request.response.close();
  }

  Future _processHealthRequest(io.HttpRequest request) async {
    if (commonServer.running && !commonServer.analysisServersRunning) {
      _logger.severe('CommonServer running without analysis servers. '
          'Intentionally failing healthcheck.');
      request.response.statusCode = io.HttpStatus.internalServerError;
    } else {
      try {
        final tempDir = await io.Directory.systemTemp.createTemp('healthz');
        try {
          final file = await io.File('${tempDir.path}/livecheck.txt');
          await file.writeAsString('testing123\n' * 1000, flush: true);
          final stat = await file.stat();
          if (stat.size > 10000) {
            request.response.statusCode = io.HttpStatus.ok;
          } else {
            request.response.statusCode = io.HttpStatus.internalServerError;
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        _logger.severe('Failed to create temporary file: $e');
        request.response.statusCode = io.HttpStatus.internalServerError;
      }
    }

    await request.response.close();
  }

  Future _processApiRequest(io.HttpRequest request) async {
    if (!discoveryEnabled) {
      apiServer.enableDiscoveryApi();
      discoveryEnabled = true;
    }
    // NOTE: We could read in the request body here and parse it similar to
    // the _parseRequest method to determine content-type and dispatch to e.g.
    // a plain text handler if we want to support that.
    final apiRequest = rpc.HttpApiRequest.fromHttpRequest(request);

    // Dartpad sends data as plain text, we need to promote this to
    // application/json to ensure that the rpc library processes it correctly
    try {
      apiRequest.headers['content-type'] = 'application/json; charset=utf-8';
      final apiResponse = await apiServer.handleHttpApiRequest(apiRequest);
      await rpc.sendApiResponse(apiResponse, request.response);
    } catch (e) {
      // This should only happen in the case where there is a bug in the rpc
      // package. Otherwise it always returns an HttpApiResponse.
      _logger.warning('Failed with error: $e when trying to call '
          'method at \'${request.uri.path}\'.');
      request.response.statusCode = io.HttpStatus.internalServerError;
      await request.response.close();
    }
  }

  Future _processDefaultRequest(io.HttpRequest request) async {
    request.response.statusCode = io.HttpStatus.notFound;
    await request.response.close();
  }
}

class GaeServerContainer implements ServerContainer {
  @override
  String get version => io.Platform.version;
}
