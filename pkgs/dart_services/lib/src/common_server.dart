// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpad_shared/model.dart' as api;
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'analysis.dart';
import 'caching.dart';
import 'compiling.dart';
import 'generative_ai.dart';
import 'project_templates.dart';
import 'pub.dart';
import 'sdk.dart';
import 'shelf_cors.dart' as shelf_cors;
import 'utils.dart';

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
  late GenerativeAI ai;

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

    ai = GenerativeAI();
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

  /// The shelf router.
  late final Router router = () {
    final router = Router();

    // general requests (GET)
    router.get(r'/api/<apiVersion>/version', handleVersion);

    // general requests (POST)
    router.post(r'/api/<apiVersion>/analyze', handleAnalyze);
    router.post(r'/api/<apiVersion>/compile', handleCompile);
    router.post(r'/api/<apiVersion>/compileDDC', handleCompileDDC);
    router.post(r'/api/<apiVersion>/complete', handleComplete);
    router.post(r'/api/<apiVersion>/fixes', handleFixes);
    router.post(r'/api/<apiVersion>/format', handleFormat);
    router.post(r'/api/<apiVersion>/document', handleDocument);
    router.post(r'/api/<apiVersion>/openInIDX', handleOpenInIdx);
    router.post(r'/api/<apiVersion>/generateCode', generateCode);
    return router;
  }();

  CommonServerApi(this.impl);

  Future<void> init() => impl.init();

  Future<void> shutdown() => impl.shutdown();

  Future<Response> handleVersion(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    return ok(version().toJson());
  }

  Future<Response> handleAnalyze(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() {
      return impl.analyzer.analyze(sourceRequest.source);
    });

    return ok(result.toJson());
  }

  Future<Response> handleCompile(Request request, String apiVersion) async {
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

  Future<Response> handleCompileDDC(Request request, String apiVersion) async {
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

  Future<Response> handleComplete(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(() =>
        impl.analyzer.complete(sourceRequest.source, sourceRequest.offset!));

    return ok(result.toJson());
  }

  Future<Response> handleFixes(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final sourceRequest =
        api.SourceRequest.fromJson(await request.readAsJson());

    final result = await serialize(
        () => impl.analyzer.fixes(sourceRequest.source, sourceRequest.offset!));

    return ok(result.toJson());
  }

  Future<Response> handleFormat(Request request, String apiVersion) async {
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

  Future<Response> handleDocument(Request request, String apiVersion) async {
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

  Future<Response> handleOpenInIdx(Request request, String apiVersion) async {
    final code = api.OpenInIdxRequest.fromJson(await request.readAsJson()).code;
    final idxUrl = Uri.parse('https://idx.google.com/run.api');

    final data = {
      'project[files][lib/main.dart]': code,
      'project[settings]': '{"baselineEnvironment": "flutter"}',
    };
    try {
      final response = await http.post(
        idxUrl,
        body: data,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      );

      if (response.statusCode == 302) {
        return ok(api.OpenInIdxResponse(idxUrl: response.headers['location']!)
            .toJson());
      } else {
        return Response.internalServerError(
            body:
                'Failed to read response from IDX server. Response: $response');
      }
    } catch (error) {
      return Response.internalServerError(
          body: 'Failed to read response from IDX server. Error: $error');
    }
  }

  @Route.post('$apiPrefix/suggestFix')
  Future<Response> suggestFix(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final suggestFixRequest =
        api.SuggestFixRequest.fromJson(await request.readAsJson());

    final result = await serialize(() {
      return impl.ai.suggestFix(
        message: suggestFixRequest.issue.message,
        line: suggestFixRequest.issue.location.line,
        column: suggestFixRequest.issue.location.column,
        source: suggestFixRequest.source,
      );
    });

    return ok(result.toJson());
  }

  @Route.post('$apiPrefix/generateCode')
  Future<Response> generateCode(Request request, String apiVersion) async {
    final logger = Logger('generateCode');
    logger.info('Received generateCode request');

    if (apiVersion != api3) return unhandledVersion(apiVersion);

    final generateCodeRequest =
        api.GenerateCodeRequest.fromJson(await request.readAsJson());

    logger.info('Prompt: ${generateCodeRequest.prompt}');

    try {
      final result = await serialize(() {
        return impl.ai.generateCode(generateCodeRequest.prompt);
      });

      logger.info('Generated code successfully');
      return ok(result.toJson());
    } catch (e) {
      logger.severe('Error generating code: $e');
      return Response.internalServerError(
          body: 'Failed to generate code. Error: $e');
    }
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
