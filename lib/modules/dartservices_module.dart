// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_services;

import 'dart:async';

import 'package:http/browser_client.dart';
import 'package:http/http.dart';

import '../core/dependencies.dart';
import '../core/modules.dart';
import '../services/common.dart';
import '../services/dartservices.dart';
import '../services/_dartpadsupportservices.dart';

// When sending requests from a browser we sanitize the headers to avoid
// client side warnings for any blacklisted headers.
class SanitizingBrowserClient extends BrowserClient {
  // The below list of disallowed browser headers is based on list at:
  // http://www.w3.org/TR/XMLHttpRequest/#the-setrequestheader()-method
  static const List<String> disallowedHeaders = const [
    'accept-charset', 'accept-encoding', 'access-control-request-headers',
    'access-control-request-method', 'connection', 'content-length', 'cookie',
    'cookie2', 'date', 'dnt', 'expect', 'host', 'keep-alive', 'origin',
    'referer', 'te', 'trailer', 'transfer-encoding', 'upgrade', 'user-agent',
    'via'
  ];

  /// Strips all disallowed headers for an HTTP request before sending it.
  Future<StreamedResponse> send(BaseRequest request) {
    for (String headerKey in disallowedHeaders) {
      request.headers.remove(headerKey);
    }

    // Replace 'application/json; charset=utf-8' with text/plain. This will
    // avoid the browser sending an OPTIONS request before the actual POST (and
    // introducing an additional round trip between the client and the server).
    request.headers['Content-Type'] = 'text/plain; charset=utf-8';

    return super.send(request);
  }
}

class DartServicesModule extends Module {
  Future init() {
    var client = new SanitizingBrowserClient();
    deps[DartservicesApi] = new DartservicesApi(client, rootUrl: serverURL);
    return new Future.value();
  }
}

class DartSupportServicesModule extends Module {
  Future init() {
    var client = new SanitizingBrowserClient();
    deps[P_dartpadsupportservicesApi] = new P_dartpadsupportservicesApi(client, rootUrl: serverURL);
    return new Future.value();
  }
}
