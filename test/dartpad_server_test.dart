// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.dartpad_server_test;

import 'dart:async';
import 'dart:convert';

import 'package:services/src/common.dart';
import 'package:services/src/dartpad_support_server.dart';
import 'package:rpc/rpc.dart';
import 'package:unittest/unittest.dart';


String quickFixesCode =
r'''
import 'dart:async';
void main() {
  int i = 0;
}
''';

String preFormattedCode =
r'''
void main()
{
int i = 0;
}
''';

String postFormattedCode =
r'''
void main() {
  int i = 0;
}
''';

void defineTests() {
  FileRelayServer server;
  ApiServer apiServer;

  server = new FileRelayServer();
  apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true);
  apiServer.addApi(server);

  Future<HttpApiResponse> _sendPostRequest(String path, json) {
    assert(apiServer != null);
    var uri = Uri.parse("/api/$path");
    var body = new Stream.fromIterable([UTF8.encode(JSON.encode(json))]);
    var request = new HttpApiRequest('POST', uri, {}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  Future<HttpApiResponse> _sendGetRequest(String path, [String queryParams]) {
    assert(apiServer != null);
    var uri = Uri.parse(
        queryParams == null ? "/api/$path" : "/api/$path?$queryParams");
    var body = new Stream.fromIterable([]);
    var request = new HttpApiRequest('GET', uri, {}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  group('ExportServer', () {

    test('Export', () async {
      var json = {'dart': sampleCode, 'html':'', 'css':''};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/export', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['uuid'] == null, false);
      var responseTwo = await _sendPostRequest('_dartpadsupportservices/v1/export', json);
      expect(responseTwo.status, 200);
      var dataTwo = JSON.decode(UTF8.decode(await responseTwo.body.first));
      expect(dataTwo['uuid'], data['uuid']);
    });

    test('Pull Export', () async {
      var json = {'dart': sampleCode, 'html':'', 'css':''};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/export', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['uuid'] == null, false);
      json = {'uuid':data['uuid']};
      var pull = await _sendPostRequest('_dartpadsupportservices/v1/pullExportData', json);
      expect(pull.status, 200);
      var pullData = JSON.decode(UTF8.decode(await pull.body.first));
      expect(pullData['dart'], sampleCode);
      expect(pullData['html'], '');
      expect(pullData['css'], '');
      expect(pullData['uuid'], data['uuid']);
    });
  });

  group('GistMapping', () {

    test('analyze negative-test noSource', () async {
       var json = {};
       var response = await _sendPostRequest('_dartpadsupportservices/v1/analyze', json);
       expect(response.status, 400);
    });

    test('compile', () async {
      var json = {'source': sampleCode};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/compile', json);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(JSON.decode(UTF8.decode(data)), isNotEmpty);
    });

    test('compile error', () async {
      var json = {'source': sampleCodeError};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/compile', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
      expect(data['error']['message'], contains('[error on line 2] Expected'));
    });

    test('compile negative-test noSource', () async {
        var json = {};
        var response = await _sendPostRequest('_dartpadsupportservices/v1/compile', json);
        expect(response.status, 400);
     });

    test('complete', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 1};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/complete', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('complete no data', () async {
      var response = await _sendPostRequest('_dartpadsupportservices/v1/complete', {});
      expect(response.status, 400);
    });

    test('complete param missing', () async {
      var json = {'offset': 1};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/complete', json);
      expect(response.status, 400);
    });

    test('complete param missing 2', () async {
      var json = {'source': 'void main() {print("foo");}'};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/complete', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 17};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 2};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {"staticType": "void"}});
    });

    test('document no data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 12};
      var response = await _sendPostRequest('_dartpadsupportservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {}});
    });

    test('document negative-test noSource', () async {
      var json = { 'offset': 12 };
      var response = await _sendPostRequest('_dartpadsupportservices/v1/document', json);
      expect(response.status, 400);
    });

    test('document negative-test noOffset', () async {
      var json = {'source': 'void main() {print("foo");}' };
      var response = await _sendPostRequest('_dartpadsupportservices/v1/document', json);
      expect(response.status, 400);
    });

    test('counter test', () async {
      var response =
        await _sendGetRequest('dartservices/v1/counter', "name=Analyses");
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(response.status, 200);
      expect(data['count'], 0);

      // Do an Analysis.
      var json = {'source': sampleCode};
      response = await _sendPostRequest('dartservices/v1/analyze', json);

      response =
        await _sendGetRequest('dartservices/v1/counter', "name=Analyses");
      data = JSON.decode(UTF8.decode(await response.body.first));
      expect(response.status, 200);
      expect(data['count'], 1);
    });

    test('format', () async {
      var json = {'source': preFormattedCode};
      var response = await _sendPostRequest('dartservices/v1/format', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data["newString"], postFormattedCode);
    });

    test('format position', () async {
      var json = {'source': preFormattedCode, 'offset': 21};
      var response = await _sendPostRequest('dartservices/v1/format', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data["newString"], postFormattedCode);
      expect(data["offset"], 24);
    });

    test('fix', () async {
      var json = {'source': quickFixesCode, 'offset': 10};
      var response = await _sendPostRequest('dartservices/v1/fixes', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      var fixes = data['fixes'];
      expect(fixes.length, 1);
      var problemAndFix = fixes[0];
      expect(problemAndFix['problemMessage'], isNotNull);
    });

    test('version', () async {
      var response = await _sendGetRequest('dartservices/v1/version');
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      print(data);
      expect(data['sdkVersion'], isNotNull);
      expect(data['runtimeVersion'], isNotNull);
    });
  });
}