// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartpad_shared/model.dart' as api;
import 'package:google_generative_ai/google_generative_ai.dart' as google_ai;
import 'package:http/http.dart' as http;
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
  final bool devtime;

  final TaskScheduler scheduler = TaskScheduler();

  /// The (lazily-constructed) router.
  late final Router router = _$CommonServerApiRouter(this);

  CommonServerApi(this.impl, {required this.devtime});

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

  @Route.post('$apiPrefix/openInIDX')
  Future<Response> openInIdx(Request request, String apiVersion) async {
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

  static final String? geminiApiKey = _envFileOrEnvironment('GEMINI_API_KEY');

  http.Client? geminiHttpClient;

  @Route.post('$apiPrefix/_gemini')
  Future<Response> gemini(Request request, String apiVersion) async {
    if (apiVersion != api3) return unhandledVersion(apiVersion);

    // Read the api key from env variables (populated on the server).
    final apiKey = geminiApiKey;
    if (apiKey == null) {
      return Response.internalServerError(
          body: 'gemini key not configured on server');
    }

    if (!devtime) {
      // Only allow the call from dartpad.dev.
      final origin = request.origin;
      if (origin != 'https://dartpad.dev') {
        return Response.badRequest(
            body: 'Gemini calls only allowed from the DartPad front-end');
      }
    }

    final geminiRequest =
        api.GeminiRequest.fromJson(await request.readAsJson());

    geminiHttpClient ??= http.Client();

    final model = google_ai.GenerativeModel(
      model: 'models/gemini-1.5-flash-latest',
      apiKey: apiKey,
      httpClient: geminiHttpClient,
    );

    final result = await serialize(() async {
      // call gemini
      final result = await model.generateContent([
        google_ai.Content.text(geminiRequest.source),
      ]);

      var text = result.text!;

      if (geminiRequest.tidySourceResponse ?? false) {
        text = await tidyGeminiSourceResponse(text);
      }

      return api.GeminiResponse(response: text);
    });

    return ok(result.toJson());
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

  Future<String> tidyGeminiSourceResponse(String text) async {
    // remove any code fences
    text = removeCodeFences(text);

    // format the code
    final formatResponse = await impl.analyzer.format(text, null);

    return formatResponse.source;
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

extension on Request {
  String? get origin => headers['origin'];
}

String? _envFileOrEnvironment(String key) {
  final envFile = File('.env');
  if (envFile.existsSync()) {
    final env = <String, String>{};
    for (final line in envFile.readAsLinesSync().map((line) => line.trim())) {
      if (line.isEmpty || line.startsWith('#')) continue;
      final split = line.indexOf('=');
      env[line.substring(0, split).trim()] = line.substring(split + 1).trim();
    }
    if (env.containsKey(key)) {
      return env[key];
    }
  }

  return Platform.environment[key];
}
