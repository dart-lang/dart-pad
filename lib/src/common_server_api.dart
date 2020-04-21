// Copyright (c) 2020, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api;

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:protobuf/protobuf.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'common_server_impl.dart' show CommonServerImpl, BadRequest;
import 'protos/dart_services.pb.dart' as proto;

export 'common_server_impl.dart' show log, ServerContainer;

part 'common_server_api.g.dart'; // generated with 'pub run build_runner build'

const PROTOBUF_CONTENT_TYPE = 'application/x-protobuf';
const JSON_CONTENT_TYPE = 'application/json; charset=utf-8';
const PROTO_API_URL_PREFIX = '/api/dartservices/<apiVersion>';

class CommonServerApi {
  final CommonServerImpl _impl;

  CommonServerApi(this._impl);

  @Route.post('$PROTO_API_URL_PREFIX/analyze')
  Future<Response> analyze(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.analyze);

  @Route.post('$PROTO_API_URL_PREFIX/compile')
  Future<Response> compile(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.CompileRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.CompileRequest.fromBuffer(bytes),
          transform: _impl.compile);

  @Route.post('$PROTO_API_URL_PREFIX/compileDDC')
  Future<Response> compileDDC(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.CompileDDCRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.CompileDDCRequest.fromBuffer(bytes),
          transform: _impl.compileDDC);

  @Route.post('$PROTO_API_URL_PREFIX/complete')
  Future<Response> complete(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.complete);

  @Route.post('$PROTO_API_URL_PREFIX/fixes')
  Future<Response> fixes(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.fixes);

  @Route.post('$PROTO_API_URL_PREFIX/assists')
  Future<Response> assists(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.assists);

  @Route.post('$PROTO_API_URL_PREFIX/format')
  Future<Response> format(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.format);

  @Route.post('$PROTO_API_URL_PREFIX/document')
  Future<Response> document(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.SourceRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.SourceRequest.fromBuffer(bytes),
          transform: _impl.document);

  @Route.post('$PROTO_API_URL_PREFIX/version')
  Future<Response> versionPost(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.VersionRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.VersionRequest.fromBuffer(bytes),
          transform: _impl.version);

  @Route.get('$PROTO_API_URL_PREFIX/version')
  Future<Response> versionGet(Request request, String apiVersion) =>
      _processRequest(request,
          decodeFromJSON: (json) =>
              proto.VersionRequest.create()..mergeFromProto3Json(json),
          decodeFromProto: (bytes) => proto.VersionRequest.fromBuffer(bytes),
          transform: _impl.version);

  Router get router => _$CommonServerApiRouter(this);

  // We are serving requests that are arriving in both Protobuf binary encoding,
  // and Protobuf JSON encoding. To handle this we need the ability to decode
  // the requests and encode the responses. We also need to know how to do the
  // work the request is requesting.

  Future<Response> _processRequest<I, O extends GeneratedMessage>(
    Request request, {
    @required I Function(List<int> bytes) decodeFromProto,
    @required I Function(Object json) decodeFromJSON,
    @required Future<O> Function(I input) transform,
  }) async {
    if (request.mimeType == PROTOBUF_CONTENT_TYPE) {
      // Dealing with binary Protobufs
      final body = <int>[];
      await for (final chunk in request.read()) {
        body.addAll(chunk);
      }
      try {
        final response = await transform(decodeFromProto(body));
        return Response.ok(
          response.writeToBuffer(),
          headers: _PROTOBUF_HEADERS,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _PROTOBUF_HEADERS,
            body: (proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .writeToBuffer());
      }
    } else {
      // Dealing with JSON encoded Protobufs
      final body = await request.readAsString();
      try {
        final response = await transform(
            decodeFromJSON(body.isNotEmpty ? json.decode(body) : {}));
        return Response.ok(
          _jsonEncoder.convert(response.toProto3Json()),
          encoding: utf8,
          headers: _JSON_HEADERS,
        );
      } on BadRequest catch (e) {
        return Response(400,
            headers: _JSON_HEADERS,
            encoding: utf8,
            body: _jsonEncoder.convert((proto.BadRequest.create()
                  ..error = (proto.ErrorMessage.create()..message = e.cause))
                .toProto3Json()));
      }
    }
  }

  final JsonEncoder _jsonEncoder = const JsonEncoder.withIndent(' ');

  static const _JSON_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': JSON_CONTENT_TYPE
  };

  static const _PROTOBUF_HEADERS = {
    'Access-Control-Allow-Origin': '*',
    'Content-Type': PROTOBUF_CONTENT_TYPE
  };
}
