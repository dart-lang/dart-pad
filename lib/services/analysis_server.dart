// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_ui.analysis_server;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'common.dart';
import 'analysis.dart';

export 'analysis.dart';

class ServerAnalysisIssueService implements AnalysisIssueService {
  Future<AnalysisResults> analyze(String source) {
    final String url = '${serverURL}/analyze';
    Map headers = {'Content-Type': 'text/plain; charset=UTF-8'};

    return HttpRequest.request(url, method: 'POST',
        requestHeaders: headers, sendData: source).then((HttpRequest request) {
      List issues = JSON.decode(request.responseText);
      return new AnalysisResults(issues.map(_convertResult).toList());
    }).catchError((e) {
      if (e is Event && e.target is HttpRequest) {
        HttpRequest request = e.target;
        throw '[${request.status} ${request.statusText}] ${request.responseText}';
      } else {
        throw e;
      }
    });
  }

  AnalysisIssue _convertResult(Map m) =>
      new AnalysisIssue(m['kind'], m['line'], m['message'],
          charStart: m['charStart'], charLength: m['charLength']);
}
