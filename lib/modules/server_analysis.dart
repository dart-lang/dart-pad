
library server_analysis;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import '../analysis.dart';
import '../dependencies.dart';
import '../modules.dart';

class ServerAnalysisModule extends Module {
  ServerAnalysisModule();

  Future init() {
    deps[AnalysisIssueService] = new ServerAnalysisIssueService();
    return new Future.value();
  }
}

class ServerAnalysisIssueService implements AnalysisIssueService {
  Future<AnalysisResults> analyze(String source) {
    final String url = 'http://localhost:8081/api/analyze';
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
