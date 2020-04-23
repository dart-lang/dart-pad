// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartservices_modules;

import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart';

// When sending requests from a browser we sanitize the headers to avoid
// client side warnings for any blacklisted headers.
class SanitizingBrowserClient extends BrowserClient {
  // The below list of disallowed browser headers is based on list at:
  // http://www.w3.org/TR/XMLHttpRequest/#the-setrequestheader()-method
  static const List<String> disallowedHeaders = <String>[
    'accept-charset',
    'accept-encoding',
    'access-control-request-headers',
    'access-control-request-method',
    'connection',
    'content-length',
    'cookie',
    'cookie2',
    'date',
    'dnt',
    'expect',
    'host',
    'keep-alive',
    'origin',
    'referer',
    'te',
    'trailer',
    'transfer-encoding',
    'upgrade',
    'user-agent',
    'via'
  ];

  /// Strips all disallowed headers for an HTTP request before sending it.
  @override
  Future<StreamedResponse> send(BaseRequest request) {
    for (final headerKey in disallowedHeaders) {
      request.headers.remove(headerKey);
    }

    return super.send(request);
  }
}
