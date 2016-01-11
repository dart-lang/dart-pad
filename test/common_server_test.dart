// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_test;

import 'dart:async';
import 'dart:convert';

import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:rpc/rpc.dart';
import 'package:services/src/common.dart';
import 'package:services/src/common_server.dart';
import 'package:unittest/unittest.dart';

import 'src/test_config.dart';

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
  CommonServer server;
  ApiServer apiServer;

  MockContainer container;
  MockCache cache;
  MockRequestRecorder recorder;
  MockCounter counter;

  String sdkPath = cli_util.getSdkDir([]).path;

  container = new MockContainer();
  cache = new MockCache();
  recorder = new MockRequestRecorder();
  counter = new MockCounter();

  server = new CommonServer(sdkPath, container, cache, recorder, counter);
  apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true);
  apiServer.addApi(server);

  onTestsFinished(() {
    server.shutdown();
  });

  Future<HttpApiResponse> _sendPostRequest(String path, json) {
    assert(apiServer != null);
    var uri = Uri.parse("/api/$path");
    var body = new Stream.fromIterable([UTF8.encode(JSON.encode(json))]);
    var request = new HttpApiRequest('POST', uri, {
      'content-type': 'application/json; charset=utf-8'
    }, body);
    return apiServer.handleHttpApiRequest(request);
  }

  Future<HttpApiResponse> _sendGetRequest(String path, [String queryParams]) {
    assert(apiServer != null);
    var uri = Uri.parse(
        queryParams == null ? "/api/$path" : "/api/$path?$queryParams");
    var body = new Stream.fromIterable([]);
    var request = new HttpApiRequest('GET', uri, {
      'content-type': 'application/json; charset=utf-8'
    }, body);
    return apiServer.handleHttpApiRequest(request);
  }

  group('CommonServer', () {
    setUp(() {
      counter.reset();
    });

    test('analyze', () async {
      var json = {'source': sampleCode};
      var response = await _sendPostRequest('dartservices/v1/analyze', json);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(JSON.decode(UTF8.decode(data)), {
        'issues': [],
        'packageImports': [],
        'resolvedImports': []
      });
    });

    test('analyze errors', () async {
      var json = {'source': sampleCodeError};
      var response = await _sendPostRequest('dartservices/v1/analyze', json);
      expect(response.status, 200);
      expect(response.headers['content-type'],
             'application/json; charset=utf-8');
      var data = await response.body.first;
      var expectedJson = {
        'issues': [
          {
            "kind": "error",
            "line": 2,
            "sourceName": "main.dart",
            "message": "Expected to find \';\'",
            "hasFixes": true,
            "charStart": 29,
            "charLength": 1,
            "location": "main.dart"
          }
        ],
        'packageImports': [],
        'resolvedImports': []
      };
      expect(JSON.decode(UTF8.decode(data)), expectedJson);
    });

    test('analyze negative-test noSource', () async {
      var json = {};
      var response = await _sendPostRequest('dartservices/v1/analyze', json);
      expect(response.status, 400);
    });

    test('compile', () async {
      var json = {'source': sampleCode};
      var response = await _sendPostRequest('dartservices/v1/compile', json);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(JSON.decode(UTF8.decode(data)), isNotEmpty);
    });

    test('compile error', () async {
      var json = {'source': sampleCodeError};
      var response = await _sendPostRequest('dartservices/v1/compile', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
      expect(data['error']['message'], contains('[error on line 2] Expected'));
    });

    test('compile negative-test noSource', () async {
      var json = {};
      var response = await _sendPostRequest('dartservices/v1/compile', json);
      expect(response.status, 400);
     });

    test('complete', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 1};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('complete no data', () async {
      var response = await _sendPostRequest('dartservices/v1/complete', {});
      expect(response.status, 400);
    });

    test('complete param missing', () async {
      var json = {'offset': 1};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 400);
    });

    test('complete param missing 2', () async {
      var json = {'source': 'void main() {print("foo");}'};
      var response = await _sendPostRequest('dartservices/v1/complete', json);
      expect(response.status, 400);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 17};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 2};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {"staticType": "void"}});
    });

    test('document no data', () async {
      var json = {'source': 'void main() {print("foo");}', 'offset': 12};
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data, {"info": {}});
    });

    test('document negative-test noSource', () async {
      var json = { 'offset': 12 };
      var response = await _sendPostRequest('dartservices/v1/document', json);
      expect(response.status, 400);
    });

    test('document negative-test noOffset', () async {
      var json = {'source': 'void main() {print("foo");}' };
      var response = await _sendPostRequest('dartservices/v1/document', json);
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

    test('summarize', () async {
      var json = {
        'sources': {'dart': sampleCode, 'html': '', 'css': ''}
      };
      var response = await _sendPostRequest('dartservices/v1/summarize', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['text'], isNotNull);
    });

    test('summarizeDifferent', () async {
      var json = {
        'sources': {'dart': sampleCode, 'html': '', 'css': ''}
      };
      var response = await _sendPostRequest('dartservices/v1/summarize', json);
      expect(response.status, 200);
      var data = JSON.decode(UTF8.decode(await response.body.first));
      expect(data['text'], isNotNull);
      var jsonTwo = {
        'sources': {'dart': quickFixesCode, 'html': '', 'css': ''}
      };
      var responseTwo =
      await _sendPostRequest('dartservices/v1/summarize', jsonTwo);
      expect(responseTwo.status, 200);
      var dataTwo = JSON.decode(UTF8.decode(await responseTwo.body.first));
      expect(dataTwo['text'], isNotNull);
      expect(dataTwo['text'] == data['text'], false);
    });
  });
}

class MockContainer implements ServerContainer {
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}

class MockRequestRecorder implements SourceRequestRecorder {
  @override
  Future record(String verb, String source, [int offset]) {
    return new Future.value();
  }
}

class MockCounter implements PersistentCounter {
  Map<String, int> counter = {};

  @override
  Future<int> getTotal(String name) {
    counter.putIfAbsent(name, () => 0);
    return new Future.value(counter[name]);
  }

  @override
  Future increment(String name, {int increment : 1}) {
    counter.putIfAbsent(name, () => 0);
    return new Future.value(counter[name]++);
  }

  void reset() => counter.clear();
}
