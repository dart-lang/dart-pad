// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services_gae;

import 'dart:io' as io;
import 'dart:math';

import 'package:appengine/appengine.dart' as ae;
import 'package:args/args.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import 'src/common_server_api.dart';
import 'src/common_server_impl.dart';
import 'src/sdk_manager.dart';
import 'src/server_cache.dart';

const String _API_PREFIX = '/api/dartservices/';
const String _livenessCheck = '/liveness_check';
const String _readinessCheck = '/readiness_check';
// Serve content for 1.5 hours, +- 30 minutes.
final DateTime _serveUntil = DateTime.now()
    .add(Duration(hours: 1))
    .add(Duration(minutes: Random().nextInt(60)));

final Logger _logger = Logger('gae_server');

void main(List<String> args) {
  final parser = ArgParser()
    ..addFlag('dark-launch', help: 'Dark launch proxied compilation requests')
    ..addOption('proxy-target',
        help: 'URL base to proxy compilation requests to')
    ..addOption('port',
        abbr: 'p', defaultsTo: '8080', help: 'Port to attach to');
  final results = parser.parse(args);

  final gaePort = int.tryParse(results['port'] as String ?? '') ?? 8080;

  if (SdkManager.sdk.sdkPath == null) {
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
    --port: $gaePort
    --dark-launch: ${results['dark-launch']}
    --proxy-target: ${results['proxy-target']}
    sdkPath: ${SdkManager.sdk?.sdkPath}
    \$REDIS_SERVER_URI: ${io.Platform.environment['REDIS_SERVER_URI']}
    \$GAE_VERSION: ${io.Platform.environment['GAE_VERSION']}
  ''');

  final server = GaeServer(
      io.Platform.environment['REDIS_SERVER_URI'],
      results['dark-launch'].toString().toLowerCase() == 'true',
      results['proxy-target'].toString());
  server.start(gaePort);
}

class GaeServer {
  final String redisServerUri;

  CommonServerImpl commonServerImpl;
  CommonServerApi commonServerApi;

  GaeServer(this.redisServerUri, bool darkLaunch, String proxyTarget) {
    hierarchicalLoggingEnabled = true;
    recordStackTraceAtLevel = Level.SEVERE;

    _logger.level = Level.ALL;

    commonServerImpl = CommonServerImpl(
      GaeServerContainer(),
      redisServerUri == null
          ? InMemoryCache()
          : RedisCache(
              redisServerUri,
              io.Platform.environment['GAE_VERSION'],
            ),
    );
    if (proxyTarget != null && proxyTarget.isNotEmpty) {
      commonServerImpl =
          CommonServerImplProxy(commonServerImpl, darkLaunch, proxyTarget);
    }
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
    } else if (request.uri.path == _readinessCheck) {
      await _processReadinessRequest(request);
    } else if (request.uri.path == _livenessCheck) {
      await _processLivenessRequest(request);
    } else if (request.uri.path.startsWith(_API_PREFIX)) {
      await shelf_io.handleRequest(request, commonServerApi.router);
    } else {
      await _processDefaultRequest(request);
    }
  }

  Future<void> _processOptionsRequest(io.HttpRequest request) async {
    final statusCode = io.HttpStatus.ok;
    request.response.statusCode = statusCode;
    await request.response.close();
  }

  Future _processReadinessRequest(io.HttpRequest request) async {
    _logger.info('Processing readiness check');
    if (!commonServerImpl.isRestarting &&
        DateTime.now().isBefore(_serveUntil)) {
      request.response.statusCode = io.HttpStatus.ok;
    } else {
      request.response.statusCode = io.HttpStatus.serviceUnavailable;
      _logger.severe('CommonServer not running - failing readiness check.');
    }

    await request.response.close();
  }

  Future _processLivenessRequest(io.HttpRequest request) async {
    _logger.info('Processing liveness check');
    if (!commonServerImpl.isHealthy || DateTime.now().isAfter(_serveUntil)) {
      _logger.severe('CommonServer is no longer healthy.'
          ' Intentionally failing health check.');
      request.response.statusCode = io.HttpStatus.serviceUnavailable;
    } else {
      try {
        final tempDir = await io.Directory.systemTemp.createTemp('healthz');
        try {
          final file = await io.File('${tempDir.path}/livecheck.txt');
          await file.writeAsString('testing123\n' * 1000, flush: true);
          final stat = await file.stat();
          if (stat.size > 10000) {
            _logger.info('CommonServer healthy and file system working.'
                ' Passing health check.');
            request.response.statusCode = io.HttpStatus.ok;
          } else {
            _logger.severe('CommonServer healthy, but filesystem is not.'
                ' Intentionally failing health check.');
            request.response.statusCode = io.HttpStatus.serviceUnavailable;
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      } catch (e) {
        _logger.severe('CommonServer healthy, but failed to create temporary'
            ' file: $e');
        request.response.statusCode = io.HttpStatus.serviceUnavailable;
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
