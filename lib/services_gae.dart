// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_gae;

import 'dart:async';
import 'dart:io' as io;

import 'package:appengine/appengine.dart' as ae;
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'src/common.dart';
import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/flutter_web.dart';
import 'src/sdk_manager.dart';
import 'src/server_cache.dart';

const String _API_PREFIX = '/api/dartservices/';
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
  CommonServerImpl commonServerImpl;
  CommonServerApi commonServerApi;

  GaeServer(this.sdkPath, this.redisServerUri) {
    hierarchicalLoggingEnabled = true;
    recordStackTraceAtLevel = Level.SEVERE;

    _logger.level = Level.ALL;

    discoveryEnabled = false;
    final flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
    commonServerImpl = CommonServerImpl(
      sdkPath,
      flutterWebManager,
      GaeServerContainer(),
      redisServerUri == null
          ? InMemoryCache()
          : RedisCache(
              redisServerUri,
              io.Platform.environment['GAE_VERSION'],
            ),
    );
    commonServerApi = CommonServerApi(commonServerImpl);
  }

  Future<dynamic> start([int gaePort = 8080]) async {
    await commonServerImpl.init();
    return ae.runAppEngine(requestHandler, port: gaePort);
  }

  Future<void> requestHandler(io.HttpRequest request) async {
    request.response.headers
      ..add('Access-Control-Allow-Origin', '*')
      ..add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
      ..add('Access-Control-Allow-Headers',
          'Origin, X-Requested-With, Content-Type, Accept');

    if (request.method == 'OPTIONS') {
      await _processOptionsRequest(request);
    } else if (request.uri.path == _readynessCheck) {
      await _processReadynessRequest(request);
    } else if (request.uri.path == _healthCheck) {
      await _processHealthRequest(request);
    } else if (request.uri.path.startsWith(_API_PREFIX)) {
      await shelf_io.handleRequest(request, commonServerApi.router.handler);
    } else {
      await _processDefaultRequest(request);
    }
  }

  Future<void> _processOptionsRequest(io.HttpRequest request) async {
    final statusCode = io.HttpStatus.ok;
    request.response.statusCode = statusCode;
    await request.response.close();
  }

  Future _processReadynessRequest(io.HttpRequest request) async {
    if (commonServerImpl.running) {
      request.response.statusCode = io.HttpStatus.ok;
    } else {
      request.response.statusCode = io.HttpStatus.internalServerError;
      _logger.info('CommonServer not running - failing readiness check.');
    }

    await request.response.close();
  }

  Future _processHealthRequest(io.HttpRequest request) async {
    if (commonServerImpl.running && !commonServerImpl.analysisServersRunning) {
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

  Future _processDefaultRequest(io.HttpRequest request) async {
    request.response.statusCode = io.HttpStatus.notFound;
    await request.response.close();
  }
}

class GaeServerContainer implements ServerContainer {
  @override
  String get version => io.Platform.version;
}
