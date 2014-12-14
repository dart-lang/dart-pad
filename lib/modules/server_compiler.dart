
library server_compiler;

import 'dart:async';
import 'dart:html';

import 'common.dart';
import '../compiler.dart';
import '../dependencies.dart';
import '../modules.dart';

class ServerCompilerModule extends Module {
  ServerCompilerModule();

  Future init() {
    deps[CompilerService] = new ServerCompilerService();
    return new Future.value();
  }
}

class ServerCompilerService extends CompilerService {
  Future<CompilerResult> compile(String source) {
    final String url = '${serverURL}/compile';
    Map headers = {'Content-Type': 'text/plain; charset=UTF-8'};

    return HttpRequest.request(url, method: 'POST',
        requestHeaders: headers, sendData: source).then((HttpRequest request) {
      return new CompilerResult(request.responseText);
    }).catchError((e) {
      if (e is Event && e.target is HttpRequest) {
        HttpRequest request = e.target;

        // `400 Bad Request` is expected on compile errors.
        if (request.status == 400) {
          throw request.responseText;
        } else {
          throw '[${request.status} ${request.statusText}] '
              '${request.responseText}';
        }
      } else {
        throw e;
      }
    });
  }
}
