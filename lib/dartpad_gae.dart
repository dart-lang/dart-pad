// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dartpad_gae;

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:appengine/appengine.dart';
import 'package:memcache/memcache.dart';

import 'src/common_server.dart';

Logging get logging => context.services.logging;
Memcache get memcache => context.services.memcache;

void main() {
  GaeServer server = new GaeServer('/usr/lib/dart');
  server.start();
}

class GaeServer {
  final String sdkPath;

  CommonServer commonServer;

  GaeServer(this.sdkPath) {
    commonServer = new CommonServer(sdkPath, new GaeLogger(), new GaeCache());
  }

  Future start() => runAppEngine(requestHandler);

  void requestHandler(io.HttpRequest request) {
    _header(request, 'Access-Control-Allow-Origin', '*');
    _header(request, 'Access-Control-Allow-Credentials', 'true');
    _header(request, 'Access-Control-Allow-Methods', 'POST, GET, OPTIONS');
    _header(request, 'Access-Control-Allow-Headers',
        'Origin, X-Requested-With, Content-Type, Accept');

    if (request.uri.path == '/api/analyze') {
      handleAnalyzePost(request);
    } else if (request.uri.path == '/api/compile') {
      handleCompilePost(request);
    } else if (request.uri.path == '/api/complete') {
      handleCompletePost(request);
    } else if (request.uri.path == '/api/document') {
      handleDocumentPost(request);
    } else {
      request.response.statusCode = io.HttpStatus.NOT_FOUND;
      request.response.close();
    }
  }

  void _header(io.HttpRequest request, String key, String value) {
    request.response.headers.add(key, value);
  }

  void handleAnalyzePost(io.HttpRequest request) {
    _getRequestData(request).then((String data) {
      String contentType = request.headers.value(io.HttpHeaders.CONTENT_TYPE);
      commonServer.handleAnalyze(data, contentType).then((response) {
        _sendResponse(request, response);
      });
    });
  }

  void handleCompilePost(io.HttpRequest request) {
    _getRequestData(request).then((String data) {
      String contentType = request.headers.value(io.HttpHeaders.CONTENT_TYPE);
      commonServer.handleCompile(data, contentType).then((response) {
        _sendResponse(request, response);
      });
    });
  }

  void handleCompletePost(io.HttpRequest request) {
    _getRequestData(request).then((String data) {
      String contentType = request.headers.value(io.HttpHeaders.CONTENT_TYPE);
      commonServer.handleComplete(data, contentType).then((response) {
        _sendResponse(request, response);
      });
    });
  }

  void handleDocumentPost(io.HttpRequest request) {
    _getRequestData(request).then((String data) {
      String contentType = request.headers.value(io.HttpHeaders.CONTENT_TYPE);
      commonServer.handleDocument(data, contentType).then((response) {
        _sendResponse(request, response);
      });
    });
  }

  void _sendResponse(io.HttpRequest request, ServerResponse response) {
    String mime = response.mimeType != null ? response.mimeType : 'text/plain';

    request.response.statusCode = response.statusCode;
    request.response.headers.set(
        io.HttpHeaders.CONTENT_TYPE, mime + '; charset=utf-8');
    request.response.write(response.data);
    request.response.close();
  }
}

class GaeLogger implements ServerLogger {
  Logging get _logging => context.services.logging;

  void info(String message) => _logging.info(message);
  void warn(String message) => _logging.warning(message);
  void error(String message) => _logging.error(message);
}

class GaeCache implements ServerCache {
  Memcache get _memcache => context.services.memcache;

  Future<String> get(String key) => _memcache.get(key);

  Future set(String key, String value, {Duration expiration}) {
    return _memcache.set(key, value, expiration: expiration);
  }

  Future remove(String key) => _memcache.remove(key);
}

Future<String> _getRequestData(io.HttpRequest request) {
  Completer<String> completer = new Completer();
  io.BytesBuilder builder = new io.BytesBuilder();

  request.listen((buffer) {
    builder.add(buffer);
  }, onDone: () {
    completer.complete(UTF8.decode(builder.toBytes()));
  });

  return completer.future;
}
