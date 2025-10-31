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

/// An abstract connection to the Dartpad backend.
///
/// Concrete implementations of this will typically either use a RESTful
/// connection or a websocket based connection.
abstract class DartPadService {
  Future<VersionResponse> version();

  Future<AnalysisResponse> analyze(SourceRequest request);

  Future<CompleteResponse> complete(SourceRequest request);

  Future<DocumentResponse> document(SourceRequest request);

  Future<FixesResponse> fixes(SourceRequest request);

  Future<FormatResponse> format(SourceRequest request);

  Future<CompileDDCResponse> compileDDC(CompileRequest request);

  Future<CompileDDCResponse> compileNewDDC(CompileRequest request);

  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request);

  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  );

  Stream<String> suggestFix(SuggestFixRequest request);

  Stream<String> generateCode(GenerateCodeRequest request);

  Stream<String> updateCode(UpdateCodeRequest request);

  Future<void> dispose();
}

/// A RESTful client to the Dartpad backend.
class DartServicesClient implements DartPadService {
  final DartServicesHttpClient client;
  final String rootUrl;

  DartServicesClient(this.client, {required this.rootUrl});

  @override
  Future<VersionResponse> version() =>
      _requestGet('version', VersionResponse.fromJson);

  @override
  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _requestPost('analyze', request.toJson(), AnalysisResponse.fromJson);

  @override
  Future<CompleteResponse> complete(SourceRequest request) =>
      _requestPost('complete', request.toJson(), CompleteResponse.fromJson);

  @override
  Future<DocumentResponse> document(SourceRequest request) =>
      _requestPost('document', request.toJson(), DocumentResponse.fromJson);

  @override
  Future<FixesResponse> fixes(SourceRequest request) =>
      _requestPost('fixes', request.toJson(), FixesResponse.fromJson);

  @override
  Future<FormatResponse> format(SourceRequest request) =>
      _requestPost('format', request.toJson(), FormatResponse.fromJson);

  @override
  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _requestPost('compileDDC', request.toJson(), CompileDDCResponse.fromJson);

  @override
  Future<CompileDDCResponse> compileNewDDC(CompileRequest request) =>
      _requestPost(
        'compileNewDDC',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  @override
  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request) =>
      _requestPost(
        'compileNewDDCReload',
        request.toJson(),
        CompileDDCResponse.fromJson,
      );

  @override
  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  ) => _requestPost(
    'openInFirebaseStudio',
    request.toJson(),
    OpenInIdxResponse.fromJson,
  );

  @override
  Stream<String> suggestFix(SuggestFixRequest request) =>
      _requestPostStream('suggestFix', request.toJson());

  @override
  Stream<String> generateCode(GenerateCodeRequest request) =>
      _requestPostStream('generateCode', request.toJson());

  @override
  Stream<String> updateCode(UpdateCodeRequest request) =>
      _requestPostStream('updateCode', request.toJson());

  @override
  Future<void> dispose() async => client.close();

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

/// A websocket client to the Dartpad backend.
class WebsocketServicesClient implements DartPadService {
  final Uri wsUrl;
  final WebSocket socket;
  final void Function(WebsocketServicesClient)? onClosed;

  final IDFactory idFactory = IDFactory();

  final Map<int, String> responseMethods = {};
  final Map<int, Completer<dynamic>> responseCompleters = {};
  final Map<int, Object Function(Map<String, Object?>)> responseDecoders = {};
  final Map<int, StreamController<String>> responseStreamControllers = {};

  WebsocketServicesClient._(this.wsUrl, this.socket, this.onClosed);

  static Future<WebsocketServicesClient> connect(
    String rootUrl, {
    void Function(WebsocketServicesClient)? onClosed,
  }) async {
    final url = Uri.parse(rootUrl);
    final wsUrl = url.replace(
      scheme: url.scheme == 'https' ? 'wss' : 'ws',
      path: 'ws',
    );
    final socket = await WebSocket.connect(wsUrl);
    final client = WebsocketServicesClient._(wsUrl, socket, onClosed);
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
          if (onClosed != null) {
            onClosed!(this);
          }
          break;
      }
    });
  }

  @override
  Future<VersionResponse> version() =>
      _sendRequest('version', VersionResponse.fromJson);

  @override
  Future<AnalysisResponse> analyze(SourceRequest request) =>
      _sendRequest('analyze', AnalysisResponse.fromJson, request.toJson());

  @override
  Future<CompleteResponse> complete(SourceRequest request) =>
      _sendRequest('complete', CompleteResponse.fromJson, request.toJson());

  @override
  Future<DocumentResponse> document(SourceRequest request) =>
      _sendRequest('document', DocumentResponse.fromJson, request.toJson());

  @override
  Future<FixesResponse> fixes(SourceRequest request) =>
      _sendRequest('fixes', FixesResponse.fromJson, request.toJson());

  @override
  Future<FormatResponse> format(SourceRequest request) =>
      _sendRequest('format', FormatResponse.fromJson, request.toJson());

  @override
  Future<CompileDDCResponse> compileDDC(CompileRequest request) =>
      _sendRequest('compileDDC', CompileDDCResponse.fromJson, request.toJson());

  @override
  Future<CompileDDCResponse> compileNewDDC(CompileRequest request) =>
      _sendRequest(
        'compileNewDDC',
        CompileDDCResponse.fromJson,
        request.toJson(),
      );

  @override
  Future<CompileDDCResponse> compileNewDDCReload(CompileRequest request) =>
      _sendRequest(
        'compileNewDDCReload',
        CompileDDCResponse.fromJson,
        request.toJson(),
      );

  @override
  Future<OpenInIdxResponse> openInFirebaseStudio(
    OpenInFirebaseStudioRequest request,
  ) => _sendRequest(
    'openInFirebaseStudio',
    OpenInIdxResponse.fromJson,
    request.toJson(),
  );

  @override
  Stream<String> suggestFix(SuggestFixRequest request) =>
      _sendRequestStream('suggestFix', request.toJson());

  @override
  Stream<String> generateCode(GenerateCodeRequest request) =>
      _sendRequestStream('generateCode', request.toJson());

  @override
  Stream<String> updateCode(UpdateCodeRequest request) =>
      _sendRequestStream('updateCode', request.toJson());

  Future<T> _sendRequest<T>(
    String method,
    Object Function(Map<String, Object?>) decoder, [
    Map<String, Object?>? params,
  ]) {
    final id = idFactory.generateNextId();
    final completer = Completer<T>();

    responseMethods[id] = method;
    responseCompleters[id] = completer;
    responseDecoders[id] = decoder;

    final request = JsonRpcRequest(method: method, id: id, params: params);
    socket.sendText(jsonEncode(request.toJson()));

    return completer.future;
  }

  Stream<String> _sendRequestStream(
    String method,
    Map<String, Object?>? params,
  ) {
    final id = idFactory.generateNextId();
    final streamController = StreamController<String>();

    responseStreamControllers[id] = streamController;

    final request = JsonRpcRequest(method: method, id: id, params: params);
    socket.sendText(jsonEncode(request.toJson()));

    return streamController.stream;
  }

  @override
  Future<void> dispose() => socket.close();

  void _dispatch(JsonRpcResponse response) {
    final id = response.id;

    if (responseCompleters.containsKey(id)) {
      final command = responseMethods.remove(id);
      final completer = responseCompleters.remove(id)!;
      final decoder = responseDecoders.remove(id)!;

      if (response.error != null) {
        final error = ApiRequestError(command!, '${response.error}');
        completer.completeError(error);
      } else {
        final result = decoder((response.result! as Map).cast());
        completer.complete(result);
      }
    } else if (responseStreamControllers.containsKey(id)) {
      // ignore: unused_local_variable
      final command = responseMethods.remove(id);
      final streamController = responseStreamControllers[id]!;
      final data = response.result as String?;

      if (data == null) {
        // Close the stream.
        streamController.close();
        responseStreamControllers.remove(id);
      } else {
        streamController.add(data);
      }
    }
  }
}

class ApiRequestError implements Exception {
  final String message;
  final String body;

  ApiRequestError(this.message, this.body);

  @override
  String toString() => '$message: $body';
}
