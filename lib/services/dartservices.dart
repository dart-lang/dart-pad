import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';
import '../src/protos/dart_services.pb.dart';
export '../src/protos/dart_services.pb.dart';

const _apiPath = 'api/dartservices/v2';

class DartservicesApi {
  DartservicesApi(this._client, {@required this.rootUrl});

  final BrowserClient _client;
  final String rootUrl;

  Future<AnalysisResults> analyze(SourceRequest request) => _request(
        'analyze',
        request,
        AnalysisResults(),
      );

  Future<AssistsResponse> assists(SourceRequest request) => _request(
        'assists',
        request,
        AssistsResponse(),
      );

  Future<CompileResponse> compile(CompileRequest request) => _request(
        'compile',
        request,
        CompileResponse(),
      );

  Future<CompileDDCResponse> compileDDC(CompileRequest request) => _request(
        'compileDDC',
        request,
        CompileDDCResponse(),
      );

  Future<CompleteResponse> complete(SourceRequest request) => _request(
        'complete',
        request,
        CompleteResponse(),
      );

  Future<DocumentResponse> document(SourceRequest request) => _request(
        'document',
        request,
        DocumentResponse(),
      );

  Future<FixesResponse> fixes(SourceRequest request) => _request(
        'fixes',
        request,
        FixesResponse(),
      );

  Future<FormatResponse> format(SourceRequest request) => _request(
        'format',
        request,
        FormatResponse(),
      );

  Future<VersionResponse> version() => _request(
        'version',
        VersionRequest(),
        VersionResponse(),
      );

  Future<O> _request<I extends GeneratedMessage, O extends GeneratedMessage>(
    String action,
    I request,
    O result,
  ) async {
    final response = await _client.post(
      '$rootUrl$_apiPath/$action',
      encoding: utf8,
      body: json.encode(request.toProto3Json()),
    );
    final jsonBody = json.decode(response.body);
    result
      ..mergeFromProto3Json(jsonBody)
      ..freeze();

    // 99 is the tag number for error message.
    if (result.getFieldOrNull(99) != null) {
      final br = BadRequest()
        ..mergeFromProto3Json(jsonBody)
        ..freeze();
      throw ApiRequestError(br.error.message);
    }

    return result;
  }
}

class ApiRequestError implements Exception {
  ApiRequestError(this.message);
  final String message;
}
