// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library test.form.server;

import 'dart:async';
import 'dart:io';

import 'package:rpc/rpc.dart';

class SimpleMessage {
  String field1;
  String field2;
}

class SimpleMixMessage {
  String field1;
  MediaMessage field2;
}

class MegaMixMessage {
  String name;
  int age;
  MediaMessage resume;
}

class MultipleFile {
  List<MediaMessage> files;
}

class MultipleFile2 {
  Map<String, MediaMessage> files;
}

@ApiClass(version: 'v1')
class TestAPI {
  @ApiResource()
  PostAPI post = new PostAPI();
}

class PostAPI {
  @ApiMethod(path: 'post/simple', method: 'POST')
  SimpleMessage test1(SimpleMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/simple-mix', method: 'POST')
  SimpleMixMessage test2(SimpleMixMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/mega-mix', method: 'POST')
  MegaMixMessage test3(MegaMixMessage message) {
    return message;
  }

  @ApiMethod(path: 'post/collection/list', method: 'POST')
  MultipleFile test4(MultipleFile message) {
    return message;
  }

  @ApiMethod(path: 'post/collection/map', method: 'POST')
  MultipleFile2 test5(MultipleFile2 message) {
    return message;
  }
}

Future main() async {
  ApiServer _apiServer = new ApiServer(apiPrefix: '', prettyPrint: true);
  _apiServer.enableDiscoveryApi();
  _apiServer.addApi(new TestAPI());

  final server = await HttpServer.bind(InternetAddress.anyIPv4, 4242);
  server.listen((HttpRequest request) {
    _apiServer.httpRequestHandler(request);
  });
}
