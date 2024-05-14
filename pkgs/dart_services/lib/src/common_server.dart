// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpad_shared/model.dart' as api;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'analysis.dart';
import 'caching.dart';
import 'compiling.dart';
import 'project_templates.dart';
import 'pub.dart';
import 'sdk.dart';
import 'shelf_cors.dart' as shelf_cors;
import 'utils.dart';

part 'common_server.g.dart';

const jsonContentType = 'application/json; charset=utf-8';

const apiPrefix = '/api/<apiVersion>';

const api3 = 'v3';

final Logger log = Logger('common_server');

class CommonServerImpl {
  final Sdk sdk;
  final ServerCache cache;
  final String storageBucket;

  late Analyzer analyzer;
  late Compiler compiler;

  CommonServerImpl(
    this.sdk,
    this.cache, {
    this.storageBucket = 'nnbd_artifacts',
  });

  Future<void> init() async {
    log.fine('initing CommonServerImpl');

    analyzer = Analyzer(sdk);
    await analyzer.init();

    compiler = Compiler(sdk, storageBucket: storageBucket);
  }

  Future<void> shutdown() async {
    log.fine('shutting down CommonServerImpl');

    await cache.shutdown();

    await analyzer.shutdown();
    await compiler.dispose();
  }
}

class CommonServerApi {
  final CommonServerImpl impl;
  final TaskScheduler scheduler = TaskScheduler();

  /// The (lazily-constructed) router.
  late final Router router = _$CommonServerApiRouter(this);

  CommonServerApi(this.impl);

  Future<void> init() => impl.init();

  Future<void> shutdown() => impl.shutdown();

  @Route.post('$apiPrefix/analyze')
  Future<Response> analyze(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() {
      return impl.analyzer.analyze(sourceRequest.source);
    });

    return ok(result.toJson());
  }

  @Route.post('$apiPrefix/compile')
  Future<Response> compile(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final results = await serialize(() {
      return impl.compiler.compile(sourceRequest.source);
    });

    if (results.hasOutput) {
      return ok(api.CompileResponse(result: results.compiledJS!).toJson());
    } else {
      return failure(results.problems.map((p) => p.message).join('\n'));
    }
  }

  @Route.post('$apiPrefix/compileDDC')
  Future<Response> compileDDC(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final results = await serialize(() {
      return impl.compiler.compileDDC(sourceRequest.source);
    });

    if (results.hasOutput) {
      var modulesBaseUrl = results.modulesBaseUrl;
      if (modulesBaseUrl != null && modulesBaseUrl.isEmpty) {
        modulesBaseUrl = null;
      }
      return ok(api.CompileDDCResponse(
        result: results.compiledJS!,
        modulesBaseUrl: modulesBaseUrl,
      ).toJson());
    } else {
      return failure(results.problems.map((p) => p.message).join('\n'));
    }
  }

  @Route.post('$apiPrefix/complete')
  Future<Response> complete(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() =>
        impl.analyzer.complete(sourceRequest.source, sourceRequest.offset!));

    return ok(result.toJson());
  }

  @Route.post('$apiPrefix/fixes')
  Future<Response> fixes(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(
        () => impl.analyzer.fixes(sourceRequest.source, sourceRequest.offset!));

    return ok(result.toJson());
  }

  @Route.post('$apiPrefix/format')
  Future<Response> format(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() {
      return impl.analyzer.format(
        sourceRequest.source,
        sourceRequest.offset,
      );
    });

    return ok(result.toJson());
  }

  @Route.post('$apiPrefix/document')
  Future<Response> document(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() {
      return impl.analyzer.dartdoc(
        sourceRequest.source,
        sourceRequest.offset!,
      );
    });

    return ok(result.toJson());
  }

  @Route.get('$apiPrefix/version')
  Future<Response> versionGet(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    return ok(version().toJson());
  }

  Response ok(Map<String, dynamic> json) {
    return Response.ok(
      _jsonEncoder.convert(json),
      encoding: utf8,
      headers: _jsonHeaders,
    );
  }

  Response failure(String message) {
    return Response.badRequest(body: message);
  }

  Response unhandledVersion(String apiVersion) {
    return Response.notFound('unhandled api version: $apiVersion');
  }

  Future<T> serialize<T>(Future<T> Function() fn) {
    return scheduler.schedule(ClosureTask(
      fn,
      timeoutDuration: const Duration(minutes: 5),
    ));
  }

  api.VersionResponse version() {
    final sdk = impl.sdk;

    final packageVersions = getPackageVersions();

    final packages = [
      for (final MapEntry(key: packageName, value: packageVersion)
          in packageVersions.entries)
        api.PackageInfo(
          name: packageName,
          version: packageVersion,
          supported: isSupportedPackage(packageName),
        ),
    ];

    return api.VersionResponse(
      dartVersion: sdk.dartVersion,
      flutterVersion: sdk.flutterVersion,
      engineVersion: sdk.engineVersion,
      serverRevision: Platform.environment['BUILD_SHA'],
      experiments: sdk.experiments,
      packages: packages,
    );
  }
}

class BadRequest implements Exception {
  final String message;

  BadRequest(this.message);

  @override
  String toString() => message;
}

final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent(' ');

const Map<String, String> _jsonHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': jsonContentType,
};

extension RequestExtension on Request {
  Future<Map<String, dynamic>> readAsJson() async {
    final body = await readAsString();
    return body.isNotEmpty
        ? (json.decode(body) as Map<String, dynamic>)
        : <String, dynamic>{};
  }
}

Middleware createCustomCorsHeadersMiddleware() {
  return shelf_cors.createCorsHeadersMiddleware(corsHeaders: <String, String>{
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers':
        'Origin, X-Requested-With, Content-Type, Accept, x-goog-api-client'
  });
}

Middleware logRequestsToLogger(Logger log) {
  return (Handler innerHandler) {
    return (request) {
      final watch = Stopwatch()..start();

      return Future.sync(() => innerHandler(request)).then((response) {
        log.info(_formatMessage(request, watch.elapsed, response: response));

        return response;
      }, onError: (Object error, StackTrace stackTrace) {
        if (error is HijackException) throw error;

        log.info(_formatMessage(request, watch.elapsed, error: error));

        // ignore: only_throw_errors
        throw error;
      });
    };
  };
}

String _formatMessage(
  Request request,
  Duration elapsedTime, {
  Response? response,
  Object? error,
}) {
  final method = request.method;
  final requestedUri = request.requestedUri;
  final statusCode = response?.statusCode;
  final bytes = response?.contentLength;
  final size = ((bytes ?? 0) + 1023) ~/ 1024;

  final ms = elapsedTime.inMilliseconds;
  final query = requestedUri.query == '' ? '' : '?${requestedUri.query}';

  var message = '${ms.toString().padLeft(5)}ms ${size.toString().padLeft(4)}k '
      '$statusCode $method ${requestedUri.path}$query';
  if (error != null) {
    message = '$message [$error]';
  }

  return message;
}
