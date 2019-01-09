// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library rpc.context;

import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gcloud/service_scope.dart' as ss;

import 'config.dart';
import 'utils.dart';

const INVOCATION_CONTEXT = #rpc.invocationContext;

InvocationContext get context => ss.lookup(INVOCATION_CONTEXT);

// Invocation context used to give access to the current request information
// in the invoked api methods.
class InvocationContext {
  // Headers passed in the current request.
  final Map<String, dynamic> requestHeaders;
  // Current request url.
  final Uri requestUri;
  // Request cookies (this is optional and not currently supported when called
  // via the shelf_rpc package).
  final List<Cookie> requestCookies;
  // The responseHeaders are used in the HTTP response returned by the server.
  // NOTE: we use a canonicalized map with a method lowercasing each key before
  // use to ensure the map will not contain duplicates due to different casing.
  final CanonicalizedMap<String, String, dynamic> responseHeaders;
  // When set overrides the default HTTP response status code.
  int responseStatusCode = null;

  InvocationContext(ParsedHttpApiRequest request)
      : requestHeaders = request.headers,
        requestUri = request.originalRequest.uri,
        requestCookies = request.originalRequest.cookies,
        responseHeaders = new CanonicalizedMap.from(
            defaultResponseHeaders, (String k) => k.toLowerCase(),
            isValidKey: (Object k) => k is String);

  // Current request base url.
  String get baseUrl {
    var url = requestUri.toString();
    return url.substring(0, url.indexOf(requestUri.path));
  }
}
