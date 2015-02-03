// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library codepad.compiler_server;

import 'dart:async';
import 'dart:html';

import 'common.dart';
import 'compiler.dart';

export 'compiler.dart';

class ServerCompilerService extends CompilerService {
  Future<CompilerResult> compile(String source) {
    final String url = '${serverURL}/compile';

    return HttpRequest.request(url, method: 'POST', sendData: source)
        .then((HttpRequest request) {
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
    }).timeout(longServiceCallTimeout);
  }
}
