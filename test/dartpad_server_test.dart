// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.dartpad_server_test;

import 'dart:async';
import 'dart:convert';

import 'package:rpc/rpc.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/dartpad_support_server.dart';
import 'package:test/test.dart';

String quickFixesCode = r'''
import 'dart:async';
void main() {
  int i = 0;
}
''';

String preFormattedCode = r'''
void main()
{
int i = 0;
}
''';

String postFormattedCode = r'''
void main() {
  int i = 0;
}
''';

void main() => defineTests();

void defineTests() {
  FileRelayServer server;
  ApiServer apiServer;

  server = new FileRelayServer(test: true);
  apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true);
  apiServer.addApi(server);

  Future<HttpApiResponse> _sendPostRequest(String path, jsonData) {
    assert(apiServer != null);
    var uri = Uri.parse("/api/$path");
    var body = new Stream.fromIterable([utf8.encode(json.encode(jsonData))]);
    var request = new HttpApiRequest(
        'POST', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  Future<HttpApiResponse> _sendGetRequest(String path, [String queryParams]) {
    assert(apiServer != null);
    var uri = Uri
        .parse(queryParams == null ? "/api/$path" : "/api/$path?$queryParams");
    var body = new Stream.fromIterable([]);
    var request = new HttpApiRequest(
        'GET', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  group('ExportServer', () {
    test('Export', () async {
      var jsonData = {'dart': 'test', 'html': '', 'css': '', 'uuid': ''};
      var response =
          await _sendPostRequest('_dartpadsupportservices/v1/export', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
    });

    test('Export uuid different', () async {
      var jsonData = {'dart': 'test', 'html': '', 'css': '', 'uuid': ''};
      var response =
          await _sendPostRequest('_dartpadsupportservices/v1/export', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var responseTwo =
          await _sendPostRequest('_dartpadsupportservices/v1/export', jsonData);
      expect(responseTwo.status, 200);
      var dataTwo = json.decode(utf8.decode(await responseTwo.body.first));
      expect(dataTwo['uuid'] == data['uuid'], false);
    });

    test('Pull export', () async {
      var jsonData = {'dart': sampleCode, 'html': '', 'css': ''};
      var response =
          await _sendPostRequest('_dartpadsupportservices/v1/export', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      jsonData = {'uuid': data['uuid']};
      var pull = await _sendPostRequest(
          '_dartpadsupportservices/v1/pullExportData', jsonData);
      expect(pull.status, 200);
      var pullData = json.decode(utf8.decode(await pull.body.first));
      expect(pullData['dart'], sampleCode);
      expect(pullData['html'], '');
      expect(pullData['css'], '');
      expect(pullData['uuid'], data['uuid']);
    });
    //TODO: Test delete functionality
  });

  group('GistMapping', () {
    test('ID request', () async {
      var response = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var responseTwo = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      expect(responseTwo.status, 200);
      var dataTwo = json.decode(utf8.decode(await responseTwo.body.first));
      expect(data['uuid'] == dataTwo['uuid'], false);
    });

    test('Store gist', () async {
      var response = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      String gistId = 'teststore';
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var jsonData = {'gistId': gistId, 'internalId': data['uuid']};
      var postResponse =
          await _sendPostRequest('_dartpadsupportservices/v1/storeGist', jsonData);
      expect(postResponse.status, 200);
      var postData = json.decode(utf8.decode(await postResponse.body.first));
      expect(postData['uuid'], gistId);
    });

    test('Store gist failure', () async {
      var response = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      String gistId = 'testfail';
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var jsonData = {'gistId': gistId, 'internalId': data['uuid']};
      var postResponse =
          await _sendPostRequest('_dartpadsupportservices/v1/storeGist', jsonData);
      expect(postResponse.status, 200);
      var postData = json.decode(utf8.decode(await postResponse.body.first));
      expect(postData['uuid'], gistId);
      jsonData = {'gistId': 'failure', 'internalId': data['uuid']};
      postResponse =
          await _sendPostRequest('_dartpadsupportservices/v1/storeGist', jsonData);
      expect(postResponse.status, 400);
    });

    test('Retrieve gist success', () async {
      var response = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      String gistId = 'testretrieve';
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var jsonData = {'gistId': gistId, 'internalId': data['uuid']};
      var postResponse =
          await _sendPostRequest('_dartpadsupportservices/v1/storeGist', jsonData);
      expect(postResponse.status, 200);
      var postData = json.decode(utf8.decode(await postResponse.body.first));
      expect(postData['uuid'], gistId);
      var getResponse = await _sendGetRequest(
          '_dartpadsupportservices/v1/retrieveGist', 'id=${data['uuid']}');
      expect(getResponse.status, 200);
      var getData = json.decode(utf8.decode(await getResponse.body.first));
      expect(getData['uuid'], gistId);
    });

    test('Retrieve gist failure', () async {
      var response = await _sendGetRequest(
          '_dartpadsupportservices/v1/getUnusedMappingId');
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['uuid'], isNotNull);
      var getResponse = await _sendGetRequest(
          '_dartpadsupportservices/v1/retrieveGist', 'id=${data['uuid']}');
      expect(getResponse.status, 400);
    });
  });
}
