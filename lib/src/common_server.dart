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

  Future<ServerResponse> handleComplete(String data, [String contentType]) {
    _RequestInput input;

    try {
      input = _parseRequest(data, contentType, true);
    } catch (e) {
      return new Future.value(new ServerResponse.badRequest('${e}'));
    }

    return new Future.value(
        new ServerResponse.notImplemented('Unimplemented: /api/complete'));
  }
}

_RequestInput _parseRequest(String data, [String contentType, bool requiresOffset = false]) {
  // This could be a plain text post of source code.
  // It could be marked as plain text, but be json encoded.
  // It could be a json post, with source and offset fields.
  // Or it could be application/x-www-form-urlencoded encoded.

  if (data == null || data.isEmpty) {
    throw "No data received";
  }

  if (contentType == null) {
    contentType = 'application/json';
  }
  if (contentType.contains(';')) {
    contentType = contentType.substring(contentType.indexOf(';'));
  }
  if (contentType == 'text/plain' && (data.startsWith('{"') || data.startsWith("{'"))) {
    contentType = 'application/json';
  }

  String source;
  int offset;

  if (contentType == 'text/plain') {
    source = data;
  } else if (contentType == 'application/json') {
    Map m = JSON.decode(data);
    source = m['source'];
    offset = m['offset'];
  } else if (contentType == 'application/x-www-form-urlencoded') {
    Map m = Uri.splitQueryString(data);
    source = m['source'];
    if (m.containsKey('offset')) {
      offset = int.parse(m['offset'], onError: (str) => null);
    }
  } else {
    // Hmm, an unknown content type.
    source = data;
  }

  if (source == null) throw "'source' parameter missing";
  if (offset == null && requiresOffset) throw "'offset' parameter missing";

  return new _RequestInput(source, offset);
}

class _RequestInput {
  final String source;
  final int offset;

  _RequestInput(this.source, [this.offset]);
}
