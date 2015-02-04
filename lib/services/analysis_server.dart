// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.analysis_server;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'common.dart';
import 'analysis.dart';

export 'analysis.dart';

class ServerAnalysisService implements AnalysisService {
  Future<AnalysisResults> analyze(String source) {
    final String url = '${serverURL}/analyze';

    return HttpRequest.request(url, method: 'POST', sendData: source)
        .then((HttpRequest request) {
      List issues = JSON.decode(request.responseText);
      return new AnalysisResults(issues.map(_convertResult).toList());
    }).catchError((e) {
      if (e is Event && e.target is HttpRequest) {
        HttpRequest request = e.target;
        throw '[${request.status} ${request.statusText}] ${request.responseText}';
      } else {
        throw e;
      }
    }).timeout(serviceCallTimeout);
  }

  // {"name":"print",
  //  "description":"print(Object object) → void",
  //  "kind":"function",
  //  "libraryName":"dart.core",
  //  "dartdoc":"Prints a string representation of the object to the console."}

  Future<Map> getDocumentation(String source, int offset) {
    final String url = '${serverURL}/document';
    String data = JSON.encode({'source': source, 'offset': offset});

    return HttpRequest.request(url, method: 'POST', sendData: data).then(
        (HttpRequest request) {
      return JSON.decode(request.responseText);
    }).catchError((e) {
      if (e is Event && e.target is HttpRequest) {
        HttpRequest request = e.target;
        throw '[${request.status} ${request.statusText}] ${request.responseText}';
      } else {
        throw e;
      }
    }).timeout(serviceCallTimeout);
  }

  AnalysisIssue _convertResult(Map m) =>
      new AnalysisIssue(m['kind'], m['line'], m['message'],
          charStart: m['charStart'], charLength: m['charLength']);
}
