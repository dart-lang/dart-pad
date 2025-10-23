// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'model.dart';

/// A request in JSON-RPC format.
class JsonRpcRequest {
  /// The name of the method to be invoked.
  final String method;

  /// The event ID; if null, this event is a notification.
  final int? id;

  /// A structured value that holds the parameter values to be used during the
  /// invocation of the method.
  final Map<String, Object?>? params;

  JsonRpcRequest({required this.method, this.id, this.params});

  factory JsonRpcRequest.fromJson(String val) {
    final json = (jsonDecode(val) as Map).cast<String, Object?>();
    return JsonRpcRequest(
      method: json['method'] as String,
      id: json['id'] as int?,
      params: (json['params'] as Map?)?.cast(),
    );
  }

  JsonRpcResponse createResultResponse(Object? result) =>
      JsonRpcResponse(id: id!, result: result);

  JsonRpcResponse createErrorResponse(Object error) =>
      JsonRpcResponse(id: id!, error: error);

  Map<String, Object?> toJson() => {
    'id': id,
    'method': method,
    if (params != null) 'params': params,
  };
}

/// A JSON-RPC response.
class JsonRpcResponse {
  /// This must be the same as the value of the id member in the request object.
  final int id;

  /// This member is required on success.
  ///
  /// This member must not exist if there was an error invoking the method.
  ///
  /// The value of this member is determined by the method invoked on the
  /// server.
  final Object? result;

  /// This member is required on error.
  ///
  /// This member must not exist if there was no error triggered during
  /// invocation.
  final Object? error;

  JsonRpcResponse({required this.id, this.result, this.error});

  factory JsonRpcResponse.fromJson(String val) {
    final json = (jsonDecode(val) as Map).cast<String, Object?>();
    return JsonRpcResponse(
      id: json['id'] as int,
      result: json['result'],
      error: json['error'],
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    if (result != null) 'result': result,
    if (error != null) 'error': error,
  };
}

/// This represents a websocket command that can be sent over the wire (aka, a
/// version command, and analyze command, ...).
abstract class WsCommand<T> {
  /// Convert this command into a websocket formatted request.
  JsonRpcRequest createRequest(IDFactory idFactory);

  /// Given a json response to this command, parse it into the expected format.
  ///
  /// For example, a `VersionCommand` might return a `VersionResponse` from this
  /// method.
  T parseResponse(Map<String, Object?> response);
}

class VersionCommand extends WsCommand<VersionResponse> {
  static const name = 'version';

  /// This command takes no parameters.
  VersionCommand();

  @override
  JsonRpcRequest createRequest(IDFactory idFactory) {
    return JsonRpcRequest(method: name, id: idFactory.generateNextId());
  }

  @override
  VersionResponse parseResponse(Map<String, Object?> response) {
    return _handleParseResponse(VersionResponse.fromJson, response);
  }
}

T _handleParseResponse<T>(
  T Function(Map<String, Object?>) decode,
  Map<String, Object?> response,
) {
  if (response.containsKey('error')) {
    // ignore: only_throw_errors
    throw response['error']!;
  } else {
    final result = (response['result'] as Map).cast<String, Object?>();
    return decode(result);
  }
}

/// A class to generate a monotonically increasing sequence of numbers.
class IDFactory {
  int _next = 0;

  int generateNextId() {
    final id = _next;
    _next++;
    return id;
  }
}
