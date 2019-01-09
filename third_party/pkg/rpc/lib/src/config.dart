// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.config;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';
import 'package:crypto/crypto.dart';
import 'package:convert/convert.dart';
import 'package:gcloud/service_scope.dart' as ss;
import 'package:uri/uri.dart';
import 'package:http_parser/http_parser.dart';

import 'context.dart';
import 'errors.dart';
import 'message.dart';
import 'utils.dart';
import 'discovery/config.dart' as discovery;
import 'http_body_parser.dart';
import 'media_message.dart';

part 'config/api.dart';
part 'config/method.dart';
part 'config/property.dart';
part 'config/resource.dart';
part 'config/schema.dart';

class ApiConfigError extends Error {
  final String message;
  ApiConfigError(this.message);

  String toString() => message;
}

class ParsedHttpApiRequest {
  /// The original request given as input.
  final HttpApiRequest originalRequest;

  final Converter<Object, dynamic> jsonToBytes;

  // The first two segments of the request path is the api name and
  // version. The key is '/name/version'.
  // The method path is the remaining path segments.
  final String apiKey;

  // Whether this request is an OPTIONS request.
  final bool isOptions;

  // Key for looking up the method group targeted by the request.
  // The key is the HTTP method followed by the number of method path segments.
  final String methodKey;

  // The method path uri for this request.
  final Uri methodUri;

  // A map from path parameter name to path parameter value.
  Map<String, String> pathParameters;

  ContentType contentType;

  factory ParsedHttpApiRequest(HttpApiRequest request, String apiPrefix,
      Converter<Object, dynamic> jsonToBytes) {
    var path = request.uri.path;
    // Get rid of any double '//' in path.
    while (path.contains('//')) path = path.replaceAll('//', '/');

    if (!path.startsWith('/')) {
      path = '/$path';
    }
    if (!apiPrefix.startsWith('/')) {
      apiPrefix = '/$apiPrefix';
    }
    if (!apiPrefix.endsWith('/')) {
      apiPrefix = '$apiPrefix/';
    }
    // Remove the api prefix plus the following '/'.
    assert(path.startsWith(apiPrefix));
    path = path.substring(apiPrefix.length);

    var pathSegments = path.split('/');
    // All HTTP api request paths must be of the form:
    //   /<apiName>/<apiVersion>/<method|resourceName>[/...].
    // Hence the number of path segments must be at least three for a valid
    // request (apiPrefix could be empty).
    if (pathSegments.length < 3) {
      throw new BadRequestError(
          'Invalid request, missing API name and/or version: ${request.uri}.');
    }
    var apiKey = '/${pathSegments[0]}/${pathSegments[1]}';
    var methodPathSegments = pathSegments.skip(2);
    var isOptions = request.httpMethod.toUpperCase() == 'OPTIONS';
    var methodKey = '${request.httpMethod}${methodPathSegments.length}';
    var methodUri = Uri.parse(methodPathSegments.join('/'));

    ContentType contentType;
    if (request.headers.containsKey(HttpHeaders.contentTypeHeader)) {
      final header = request.headers[HttpHeaders.contentTypeHeader];

      if (header is List) {
        contentType = ContentType.parse(header.join(' '));
      } else {
        contentType = ContentType.parse(header);
      }
    }
    return new ParsedHttpApiRequest._(request, apiKey, isOptions, methodKey,
        methodUri, jsonToBytes, contentType);
  }

  ParsedHttpApiRequest._(this.originalRequest, this.apiKey, this.isOptions,
      this.methodKey, this.methodUri, this.jsonToBytes, this.contentType);

  String get httpMethod => originalRequest.httpMethod;

  String get path => originalRequest.uri.path;

  Map<String, String> get queryParameters =>
      originalRequest.uri.queryParameters;

  Map<String, dynamic> get headers => originalRequest.headers;

  Stream<List<int>> get body => originalRequest.body;
}

/// Helper class describing a method parameter.
class ApiParameter {
  final String name;
  Symbol symbol;
  bool isInt;
  bool isBool;

  ApiParameter(this.name, ParameterMirror pm) {
    this.symbol = pm.simpleName;
    isInt = pm.type == reflectType(int);
    isBool = pm.type == reflectType(bool);
  }
}
