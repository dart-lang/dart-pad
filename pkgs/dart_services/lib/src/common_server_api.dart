// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'common_server_impl.dart' show BadRequest, CommonServerImpl;
import 'project.dart';
import 'protos/dart_services.pb.dart' as proto;
import 'pub.dart';
import 'scheduler.dart';
import 'shared/model.dart' as api;
import 'shelf_cors.dart' as shelf_cors;

export 'common_server_impl.dart' show log;

part 'common_server_api.g.dart';

const protobufContentType = 'application/x-protobuf';
const jsonContentType = 'application/json; charset=utf-8';

const oldApiPrefix = '/api/dartservices/<apiVersion>';
const newApiPrefix = '/api/<apiVersion>';

const api2 = 'v2';
const api3 = 'v3';

class CommonServerApi {
  final CommonServerImpl _impl;
  final TaskScheduler scheduler = TaskScheduler();

  CommonServerApi(this._impl);

  @Route.post('$oldApiPrefix/analyze')
  @Route.post('$newApiPrefix/analyze')
  Future<Response> analyze(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.analyze,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());

      final result = await serialize(() {
        return _impl.analysisServer.analyze(sourceRequest.source);
      });

      return ok(api.AnalysisResponse(
        issues: result.issues.map((issue) {
          return api.AnalysisIssue(
            kind: issue.kind,
            message: issue.message,
            correction: issue.hasCorrection() ? issue.correction : null,
            url: issue.hasUrl() ? issue.url : null,
            charStart: issue.charStart,
            charLength: issue.charLength,
            line: issue.line,
            column: issue.column,
          );
        }).toList(),
        packageImports: result.packageImports,
      ).toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/compile')
  @Route.post('$newApiPrefix/compile')
  Future<Response> compile(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.CompileRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.CompileRequest.fromBuffer,
        transform: _impl.compile,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());
      final results = await serialize(() {
        return _impl.compiler.compile(sourceRequest.source);
      });
      if (results.hasOutput) {
        return ok(api.CompileResponse(result: results.compiledJS!).toJson());
      } else {
        return failure(results.problems.map((p) => p.message).join('\n'));
      }
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/compileDDC')
  @Route.post('$newApiPrefix/compileDDC')
  Future<Response> compileDDC(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.CompileDDCRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.CompileDDCRequest.fromBuffer,
        transform: _impl.compileDDC,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());
      final results = await serialize(() {
        return _impl.compiler.compileDDC(sourceRequest.source);
      });
      if (results.hasOutput) {
        return ok(api.CompileDDCResponse(
          result: results.compiledJS!,
          modulesBaseUrl: results.modulesBaseUrl!,
        ).toJson());
      } else {
        return failure(results.problems.map((p) => p.message).join('\n'));
      }
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @experimental
  @Route.post('$oldApiPrefix/_flutterBuild')
  @Route.post('$newApiPrefix/_flutterBuild')
  Future<Response> flutterBuild(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.flutterBuild,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());
      final results = await serialize(() {
        return _impl.compiler.flutterBuild(sourceRequest.source);
      });

      if (results.hasOutput) {
        return ok(api.FlutterBuildResponse(
          artifacts: {
            'main.dart.js': results.compiledJavaScript!,
          },
        ).toJson());
      } else {
        return failure(results.compilationIssues ?? '');
      }
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/complete')
  @Route.post('$newApiPrefix/complete')
  Future<Response> complete(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.complete,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());
      final result = await serialize(() => _impl.analysisServer
          .completeV3(sourceRequest.source, sourceRequest.offset!));
      return ok(result.toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/fixes')
  @Route.post('$newApiPrefix/fixes')
  Future<Response> fixes(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.fixes,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());
      final result = await serialize(() => _impl.analysisServer
          .fixesV3(sourceRequest.source, sourceRequest.offset!));
      return ok(result.toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/assists')
  @Route.post('$newApiPrefix/assists')
  Future<Response> assists(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.assists,
      );
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/format')
  @Route.post('$newApiPrefix/format')
  Future<Response> format(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.format,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());

      final result = await serialize(() {
        return _impl.analysisServer.format(
          sourceRequest.source,
          sourceRequest.offset,
        );
      });
      return ok(api.FormatResponse(
        source: result.newString,
        offset: result.offset,
      ).toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/document')
  @Route.post('$newApiPrefix/document')
  Future<Response> document(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.SourceRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.SourceRequest.fromBuffer,
        transform: _impl.document,
      );
    } else if (apiVersion == api3) {
      final sourceRequest =
          api.SourceRequest.fromJson(await request.readAsJson());

      final result = await serialize(() {
        return _impl.analysisServer.dartdocV3(
          sourceRequest.source,
          sourceRequest.offset!,
        );
      });
      return ok(result.toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.post('$oldApiPrefix/version')
  @Route.post('$newApiPrefix/version')
  Future<Response> versionPost(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.VersionRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.VersionRequest.fromBuffer,
        transform: _impl.version,
      );
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  @Route.get('$oldApiPrefix/version')
  @Route.get('$newApiPrefix/version')
  Future<Response> versionGet(Request request, String apiVersion) async {
    if (apiVersion == api2) {
      return _processRequest(
        request,
        decodeFromJSON: (json) =>
            proto.VersionRequest.create()..mergeFromProto3Json(json),
        decodeFromProto: proto.VersionRequest.fromBuffer,
        transform: _impl.version,
      );
    } else if (apiVersion == api3) {
      return ok(version().toJson());
    } else {
      return unhandledVersion(apiVersion);
    }
  }

  // Beginning of multi file map end points:
  @Route.post('$oldApiPrefix/analyzeFiles')
  @Route.post('$newApiPrefix/analyzeFiles')
  Future<Response> analyzeFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.SourceFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.SourceFilesRequest.fromBuffer,
      transform: _impl.analyzeFiles,
    );
  }

  @Route.post('$oldApiPrefix/compileFiles')
  @Route.post('$newApiPrefix/compileFiles')
  Future<Response> compileFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.CompileFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.CompileFilesRequest.fromBuffer,
      transform: _impl.compileFiles,
    );
  }

  @Route.post('$oldApiPrefix/compileFilesDDC')
  @Route.post('$newApiPrefix/compileFilesDDC')
  Future<Response> compileFilesDDC(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.CompileFilesDDCRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.CompileFilesDDCRequest.fromBuffer,
      transform: _impl.compileFilesDDC,
    );
  }

  @Route.post('$oldApiPrefix/completeFiles')
  @Route.post('$newApiPrefix/completeFiles')
  Future<Response> completeFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.SourceFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.SourceFilesRequest.fromBuffer,
      transform: _impl.completeFiles,
    );
  }

  @Route.post('$oldApiPrefix/fixesFiles')
  @Route.post('$newApiPrefix/fixesFiles')
  Future<Response> fixesFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.SourceFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.SourceFilesRequest.fromBuffer,
      transform: _impl.fixesFiles,
    );
  }

  @Route.post('$oldApiPrefix/assistsFiles')
  @Route.post('$newApiPrefix/assistsFiles')
  Future<Response> assistsFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.SourceFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.SourceFilesRequest.fromBuffer,
      transform: _impl.assistsFiles,
    );
  }

  @Route.post('$oldApiPrefix/documentFiles')
  @Route.post('$newApiPrefix/documentFiles')
  Future<Response> documentFiles(Request request, String apiVersion) {
    return _processRequest(
      request,
      decodeFromJSON: (json) =>
          proto.SourceFilesRequest.create()..mergeFromProto3Json(json),
      decodeFromProto: proto.SourceFilesRequest.fromBuffer,
      transform: _impl.documentFiles,
    );
  }

  // *** //

  Response ok(Map<String, dynamic> json) {
    return Response.ok(_jsonEncoder.convert(json),
        encoding: utf8, headers: _jsonHeaders);
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
    final sdk = _impl.sdk;

    final packageVersions = getPackageVersions();
    final packages = [
      for (final packageName in packageVersions.keys)
        api.PackageInfo(
          name: packageName,
          version: packageVersions[packageName]!,
          supported: isSupportedPackage(packageName),
        ),
    ];

    return api.VersionResponse(
      dartVersion: sdk.versionFull,
      flutterVersion: sdk.flutterVersion,
      engineVersion: sdk.engineVersion,
      experiments: sdk.experiments,
      packages: packages,
    );
  }

  /// The (lazily-constructed) router.
  late final Router router = _$CommonServerApiRouter(this);

  // We are serving requests that are arriving in both Protobuf binary encoding,
  // and Protobuf JSON encoding. To handle this we need the ability to decode
  // the requests and encode the responses. We also need to know how to do the
  // work the request is requesting.

  Future<Response> _processRequest<I, O extends GeneratedMessage>(
    Request request, {
    required I Function(List<int> bytes) decodeFromProto,
    required I Function(Object json) decodeFromJSON,
    required Future<O> Function(I input) transform,
  }) async {
    return scheduler.schedule(_ServerTask(
      request,
      decodeFromProto: decodeFromProto,
      decodeFromJSON: decodeFromJSON,
      transform: transform,
    ));
  }
}

final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent(' ');

const _jsonHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': jsonContentType,
};

const _protobufHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Content-Type': protobufContentType,
};

class _ServerTask<I, O extends GeneratedMessage> extends Task<Response> {
  final Request request;
  final I Function(List<int> bytes) decodeFromProto;
  final I Function(Object json) decodeFromJSON;
  final Future<O> Function(I input) transform;

  _ServerTask(
    this.request, {
    required this.decodeFromProto,
    required this.decodeFromJSON,
    required this.transform,
  });

  @override
  Duration get timeoutDuration => const Duration(minutes: 5);

  @override
  Future<Response> perform() async {
    if (request.mimeType == protobufContentType) {
      // Dealing with binary Protobufs
      final body = <int>[];
      await for (final chunk in request.read()) {
        body.addAll(chunk);
      }
      try {
        final response = await transform(decodeFromProto(body));
        return Response.ok(
          response.writeToBuffer(),
          headers: _protobufHeaders,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _protobufHeaders,
            body: (proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .writeToBuffer());
      }
    } else {
      // Dealing with JSON encoded Protobufs
      final body = await request.readAsString();
      try {
        final response = await transform(
            decodeFromJSON(body.isNotEmpty ? json.decode(body) as Object : {}));
        return Response.ok(
          _jsonEncoder.convert(response.toProto3Json()),
          encoding: utf8,
          headers: _jsonHeaders,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _jsonHeaders,
            encoding: utf8,
            body: _jsonEncoder.convert((proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .toProto3Json()));
      }
    }
  }
}

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
