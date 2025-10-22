// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket/web_socket.dart';

import 'backend_client.dart';
import 'model.dart';
import 'ws.dart';

export 'model.dart';

class DartServicesClient {
  final DartServicesHttpClient client;
  final String rootUrl;

  DartServicesClient(this.client, {required this.rootUrl});

  @Deprecated('prefer the websocket version')
  Future<VersionResponse> version() =>
      _requestGet('version', VersionResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _requestPost('analyze', request.toJson(), AnalysisResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<CompleteResponse> complete(SourceRequest request) =>
      _requestPost('complete', request.toJson(), CompleteResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<DocumentResponse> document(SourceRequest request) =>
      _requestPost('document', request.toJson(), DocumentResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<FixesResponse> fixes(SourceRequest request) =>
      _requestPost('fixes', request.toJson(), FixesResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<FormatResponse> format(SourceRequest request) =>
      _requestPost('format', request.toJson(), FormatResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _requestPost('compileDDC', request.toJson(), CompileDDCResponse.fromJson);

  @Deprecated('prefer the websocket version')
  Future<CompileDDCResponse> compileNewDDC(CompileRequest request) =>
      _requestPost(
        'compileNewDDC',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  @Deprecated('prefer the websocket version')
  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request) =>
      _requestPost(
        'compileNewDDCReload',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  @Deprecated('prefer the websocket version')
  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  ) => _requestPost(
    'openInFirebaseStudio',
    request.toJson(),
    OpenInIdxResponse.fromJson,
  );

  Stream<String> suggestFix(SuggestFixRequest request) =>
      _requestPostStream('suggestFix', request.toJson());

  Stream<String> generateCode(GenerateCodeRequest request) =>
      _requestPostStream('generateCode', request.toJson());

  Stream<String> updateCode(UpdateCodeRequest request) =>
      _requestPostStream('updateCode', request.toJson());

  void dispose() => client.close();

  Future<T> _requestGet<T>(
    String action,
    T Function(Map<String, Object?> json) responseFactory,
  ) async {
    final response = await client.get('${rootUrl}api/v3/$action');

    if (response.statusCode != 200) {
      throw ApiRequestError(action, response.body);
    } else {
      try {
        return responseFactory(
          json.decode(response.body) as Map<String, Object?>,
        );
      } on FormatException catch (e) {
        throw ApiRequestError('$action: $e', response.body);
      }
    }
  }

  Future<T> _requestPost<T>(
    String action,
    Map<String, Object?> request,
    T Function(Map<String, Object?> json) responseFactory,
  ) async {
    final response = await client.post('${rootUrl}api/v3/$action', request);
    if (response.statusCode != 200) {
      throw ApiRequestError(action, response.body);
    } else {
      try {
        return responseFactory(
          json.decode(response.body) as Map<String, Object?>,
        );
      } on FormatException catch (e) {
        throw ApiRequestError('$action: $e', response.body);
      }
    }
  }

  Stream<String> _requestPostStream(
    String action,
    Map<String, Object?> request,
  ) async* {
    final response = await client.sendJson('${rootUrl}api/v3/$action', request);

    if (response.statusCode != 200) {
      throw ApiRequestError(
        action,
        '${response.statusCode}: ${response.reasonPhrase}',
      );
    }

    try {
      yield* response.stream.transform(utf8.decoder);
    } on FormatException catch (e) {
      throw ApiRequestError('$action: $e', '');
    }
  }
}

/// A websocket analog to [DartServicesClient].
class WebsocketServicesClient {
  final Uri wsUrl;
  final WebSocket socket;
  final IDFactory idFactory = IDFactory();

  final Map<int, Completer<dynamic>> responseCompleters = {};
  final Map<int, Object Function(Map<String, Object?>)> responseDecoders = {};

  final Completer<void> _closedCompleter = Completer();

  WebsocketServicesClient._(this.wsUrl, this.socket);

  static Future<WebsocketServicesClient> connect(String rootUrl) async {
    final url = Uri.parse(rootUrl);
    final wsUrl = url.replace(
      scheme: url.scheme == 'https' ? 'wss' : 'ws',
      path: 'ws',
    );
    final socket = await WebSocket.connect(wsUrl);
    final client = WebsocketServicesClient._(wsUrl, socket);
    client._init();
    return client;
  }

  void _init() {
    socket.events.listen((e) async {
      switch (e) {
        case TextDataReceived(text: final text):
          _dispatch(JsonRpcResponse.fromJson(text));
          break;
        case BinaryDataReceived(data: final _):
          // Ignore - binary data is unsupported.
          break;
        case CloseReceived(code: final _, reason: final _):
          // Notify that the server connection has closed.
          _closedCompleter.complete();
          break;
      }
    });
  }

  Future<void> get onClosed => _closedCompleter.future;

  Future<VersionResponse> version() =>
      _sendRequest('version', VersionResponse.fromJson);

  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _sendRequest('analyze', AnalysisResponse.fromJson, request.toJson());

  Future<CompleteResponse> complete(SourceRequest request) =>
      _sendRequest('complete', CompleteResponse.fromJson, request.toJson());

  Future<DocumentResponse> document(SourceRequest request) =>
      _sendRequest('document', DocumentResponse.fromJson, request.toJson());

  Future<FixesResponse> fixes(SourceRequest request) =>
      _sendRequest('fixes', FixesResponse.fromJson, request.toJson());

  Future<FormatResponse> format(SourceRequest request) =>
      _sendRequest('format', FormatResponse.fromJson, request.toJson());

  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _sendRequest('compileDDC', CompileDDCResponse.fromJson, request.toJson());

  Future<CompileDDCResponse> compileNewDDC(CompileRequest request) =>
      _sendRequest(
        'compileNewDDC',
        CompileDDCResponse.fromJson,
        request.toJson(),
      );

  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request) =>
      _sendRequest(
        'compileNewDDCReload',
        CompileDDCResponse.fromJson,
        request.toJson(),
      );

  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  ) => _sendRequest(
    'openInFirebaseStudio',
    OpenInIdxResponse.fromJson,
    request.toJson(),
  );

  // todo: support streaming responses over websockets

  // // todo:
  // Stream<String> suggestFix(SuggestFixRequest request) =>
  //     _requestPostStream('suggestFix', request.toJson());

  // // todo:
  // Stream<String> generateCode(GenerateCodeRequest request) =>
  //     _requestPostStream('generateCode', request.toJson());

  // // todo:
  // Stream<String> updateCode(UpdateCodeRequest request) =>
  //     _requestPostStream('updateCode', request.toJson());

  Future<T> _sendRequest<T>(
    String method,
    Object Function(Map<String, Object?>) decoder, [
    Map<String, Object?>? params,
  ]) {
    final id = idFactory.generateNextId();
    final completer = Completer<T>();

    responseCompleters[id] = completer;
    responseDecoders[id] = decoder;

    final request = JsonRpcRequest(method: method, id: id, params: params);
    socket.sendText(jsonEncode(request.toJson()));

    return completer.future;
  }

  Future<void> dispose() => socket.close();

  void _dispatch(JsonRpcResponse response) {
    final id = response.id;

    final completer = responseCompleters[id]!;
    final decoder = responseDecoders[id]!;

    if (response.error != null) {
      completer.completeError(response.error!);
    } else {
      final result = decoder((response.result! as Map).cast());
      completer.complete(result);
    }
  }
}

class ApiRequestError implements Exception {
  ApiRequestError(this.message, this.body);

  final String message;
  final String body;

  @override
  String toString() => '$message: $body';
}
