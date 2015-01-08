// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_server.common_server;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'analyzer.dart';
import 'compiler.dart';

abstract class ServerLogger {
  void info(String message);
}

abstract class ServerCache {
  Future<String> get(String key);
  Future set(String key, String value, {Duration expiration});
  Future remove(String key);
}

class ServerResponse {
  final int statusCode;
  final String data;
  final String mimeType;

  ServerResponse(this.statusCode, this.data, [this.mimeType]);

  ServerResponse.badRequest(this.data):
    statusCode = HttpStatus.BAD_REQUEST, mimeType = null;

  ServerResponse.notImplemented(this.data):
    statusCode = HttpStatus.NOT_IMPLEMENTED, mimeType = null;

  String toString() => '[response ${statusCode}]';
}

class CommonServer {
  final ServerLogger logger;
  final ServerCache cache;

  Analyzer analyzer;
  Compiler compiler;

  CommonServer(String sdkPath, this.logger, this.cache) {
    analyzer = new Analyzer(sdkPath);
    compiler = new Compiler(sdkPath);
  }

  Future<ServerResponse> handleComplete(String data) {
    if (data.isEmpty) {
      return new Future.value(
          new ServerResponse.badRequest("No JSON data received"));
    }

    Map m = JSON.decode(data);

    String source = m['source'];
    if (source == null) {
      return new Future.value(
          new ServerResponse.badRequest("'source' parameter missing"));
    }

    int offset = m['offset'];
    if (offset == null) {
      return new Future.value(
          new ServerResponse.badRequest("'offset' parameter missing"));
    }

    return new Future.value(
        new ServerResponse.notImplemented('Unimplemented: /api/complete'));
  }
}
