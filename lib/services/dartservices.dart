import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';
import '../src/protos/dart_services.pb.dart';

export '../src/protos/dart_services.pb.dart'
    show
        AnalysisIssue,
        AnalysisResults,
        AssistsResponse,
        CompileRequest,
        CompileResponse,
        CompleteResponse,
        Completion,
        CompileDDCResponse,
        DocumentResponse,
        FixesResponse,
        FormatResponse,
        SourceRequest,
        VersionResponse;

const _apiPath = 'api/dartservices/v2';

class DartservicesApi {
  DartservicesApi(this._client, {@required this.rootUrl});

  final BrowserClient _client;
  final String rootUrl;

  Future<AnalysisResults> analyze(SourceRequest request) => _request(
        'analyze',
        request,
        AnalysisResults.create,
      );

  Future<AssistsResponse> assists(SourceRequest request) => _request(
        'assists',
        request,
        AssistsResponse.create,
      );

  Future<CompileResponse> compile(CompileRequest request) => _request(
        'compile',
        request,
        CompileResponse.create,
      );

  Future<CompileDDCResponse> compileDDC(CompileRequest request) => _request(
        'compileDDC',
        request,
        CompileDDCResponse.create,
      );

  Future<CompleteResponse> complete(SourceRequest request) => _request(
        'complete',
        request,
        CompleteResponse.create,
      );

  Future<DocumentResponse> document(SourceRequest request) => _request(
        'document',
        request,
        DocumentResponse.create,
      );

  Future<FixesResponse> fixes(SourceRequest request) => _request(
        'fixes',
        request,
        FixesResponse.create,
      );

  Future<FormatResponse> format(SourceRequest request) => _request(
        'format',
        request,
        FormatResponse.create,
      );

  Future<VersionResponse> version() => _request(
        'version',
        VersionRequest(),
        VersionResponse.create,
      );

  Future<O> _request<I extends GeneratedMessage, O extends GeneratedMessage>(
    String action,
    I request,
    O Function() res,
  ) async {
    final response = await _client.post(
      '$rootUrl$_apiPath/$action',
      encoding: utf8,
      body: json.encode(request.toProto3Json()),
    );
    return res()..mergeFromProto3Json(json.decode(response.body));
  }
}
