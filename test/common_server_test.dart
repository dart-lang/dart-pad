// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_test;

import 'dart:async';
import 'dart:convert';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
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

String formatBadCode = r'''
void main()
{
  print('foo')
}
''';

void main() => defineTests();

void defineTests() {
  CommonServer server;
  ApiServer apiServer;

  MockContainer container;
  MockCache cache;
  MockCounter counter;

  Future<HttpApiResponse> _sendPostRequest(String path, jsonData) {
    assert(apiServer != null);
    var uri = Uri.parse("/api/$path");
    var body = Stream.fromIterable([utf8.encode(json.encode(jsonData))]);
    var request = HttpApiRequest(
        'POST', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  Future<HttpApiResponse> _sendGetRequest(String path, [String queryParams]) {
    assert(apiServer != null);
    var uri = Uri.parse(
        queryParams == null ? "/api/$path" : "/api/$path?$queryParams");
    var body = Stream<List<int>>.fromIterable([]);
    var request = HttpApiRequest(
        'GET', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  group('CommonServer', () {
    setUpAll(() async {
      container = MockContainer();
      cache = MockCache();
      counter = MockCounter();

      server = CommonServer(sdkPath, container, cache, counter);
      await server.init();
      await server.warmup();

      apiServer = ApiServer(apiPrefix: '/api', prettyPrint: true);
      apiServer.addApi(server);

      // Some piece of initialization doesn't always happen fast enough for
      // this request to work in time for the test.  So try it here until the
      // server returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = {};
        var jsonData = {'source': sampleCodeError};
        while (decodedJson.isEmpty) {
          var response =
              await _sendPostRequest('dartservices/v1/analyze', jsonData);
          expect(response.status, 200);
          expect(response.headers['content-type'],
              'application/json; charset=utf-8');
          var data = await response.body.first;
          decodedJson = json.decode(utf8.decode(data));
        }
      }
    });

    tearDownAll(() {
      return server.shutdown();
    });

    setUp(() {
      counter.reset();
      log.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    });

    tearDown(() {
      log.clearListeners();
    });

    test('analyze', () async {
      var jsonData = {'source': sampleCode};
      var response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(
          json.decode(utf8.decode(data)), {'issues': [], 'packageImports': []});
    });

    test('analyze errors', () async {
      var jsonData = {'source': sampleCodeError};
      var response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 200);
      expect(
          response.headers['content-type'], 'application/json; charset=utf-8');
      var data = await response.body.first;
      var expectedJson = {
        'issues': [
          {
            "kind": "error",
            "line": 2,
            "sourceName": "main.dart",
            "message": "Expected to find \';\'.",
            "hasFixes": true,
            "charStart": 29,
            "charLength": 1
          }
        ],
        'packageImports': []
      };
      expect(json.decode(utf8.decode(data)), expectedJson);
    });

    test('analyze negative-test noSource', () async {
      var jsonData = {};
      var response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 400);
    });

    test('compile', () async {
      var jsonData = {'source': sampleCode};
      var response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 200);
      var data = await response.body.first;
      expect(json.decode(utf8.decode(data)), isNotEmpty);
    });

    test('compile error', () async {
      var jsonData = {'source': sampleCodeError};
      var response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 400);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
      expect(data['error']['message'], contains('Error: Expected'));
    });

    test('compile negative-test noSource', () async {
      var jsonData = {};
      var response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 400);
    });

    test('complete', () async {
      var jsonData = {'source': 'void main() {print("foo");}', 'offset': 1};
      var response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('complete no data', () async {
      var response = await _sendPostRequest('dartservices/v1/complete', {});
      expect(response.status, 400);
    });

    test('complete param missing', () async {
      var jsonData = {'offset': 1};
      var response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 400);
    });

    test('complete param missing 2', () async {
      var jsonData = {'source': 'void main() {print("foo");}'};
      var response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 400);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      var jsonData = {'source': 'void main() {print("foo");}', 'offset': 17};
      var response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      var jsonData = {'source': 'void main() {print("foo");}', 'offset': 2};
      var response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data, {
        "info": {"staticType": "void"}
      });
    });

    test('document no data', () async {
      var jsonData = {'source': 'void main() {print("foo");}', 'offset': 12};
      var response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data, {"info": {}});
    });

    test('document negative-test noSource', () async {
      var jsonData = {'offset': 12};
      var response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 400);
    });

    test('document negative-test noOffset', () async {
      var jsonData = {'source': 'void main() {print("foo");}'};
      var response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 400);
    });

    test('counter test', () async {
      var response =
          await _sendGetRequest('dartservices/v1/counter', "name=Analyses");
      var data = json.decode(utf8.decode(await response.body.first));
      expect(response.status, 200);
      expect(data['count'], 0);

      // Do an Analysis.
      var jsonData = {'source': sampleCode};
      response = await _sendPostRequest('dartservices/v1/analyze', jsonData);

      response =
          await _sendGetRequest('dartservices/v1/counter', "name=Analyses");
      data = json.decode(utf8.decode(await response.body.first));
      expect(response.status, 200);
      expect(data['count'], 1);
    });

    test('format', () async {
      var jsonData = {'source': preFormattedCode};
      var response = await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data["newString"], postFormattedCode);
    });

    test('format bad code', () async {
      var jsonData = {'source': formatBadCode};
      var response = await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data["newString"], formatBadCode);
    });

    test('format position', () async {
      var jsonData = {'source': preFormattedCode, 'offset': 21};
      var response = await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data["newString"], postFormattedCode);
      expect(data["offset"], 24);
    });

    test('fix', () async {
      var jsonData = {'source': quickFixesCode, 'offset': 10};
      var response = await _sendPostRequest('dartservices/v1/fixes', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      var fixes = data['fixes'];
      expect(fixes.length, 1);
      var problemAndFix = fixes[0];
      expect(problemAndFix['problemMessage'], isNotNull);
    });

    test('version', () async {
      var response = await _sendGetRequest('dartservices/v1/version');
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['sdkVersion'], isNotNull);
      expect(data['runtimeVersion'], isNotNull);
    });

    test('summarize', () async {
      Map<String, dynamic> jsonData = {
        'sources': <String, String>{'dart': sampleCode, 'html': '', 'css': ''}
      };
      var response =
          await _sendPostRequest('dartservices/v1/summarize', jsonData);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['text'], isNotNull);
    }, skip: 'Disable until rpc fix is available');

    test('summarizeDifferent', () async {
      var jsonOne = {
        'sources': {'dart': sampleCode, 'html': '', 'css': ''}
      };
      var response =
          await _sendPostRequest('dartservices/v1/summarize', jsonOne);
      expect(response.status, 200);
      var data = json.decode(utf8.decode(await response.body.first));
      expect(data['text'], isNotNull);
      var jsonTwo = {
        'sources': {'dart': quickFixesCode, 'html': '', 'css': ''}
      };
      var responseTwo =
          await _sendPostRequest('dartservices/v1/summarize', jsonTwo);
      expect(responseTwo.status, 200);
      var dataTwo = json.decode(utf8.decode(await responseTwo.body.first));
      expect(dataTwo['text'], isNotNull);
      expect(dataTwo['text'] == data['text'], false);
    }, skip: 'Disable until rpc fix is available');
  });
}

class MockContainer implements ServerContainer {
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  Future<String> get(String key) => Future.value(null);
  Future set(String key, String value, {Duration expiration}) => Future.value();
  Future remove(String key) => Future.value();
}

class MockCounter implements PersistentCounter {
  Map<String, int> counter = {};

  @override
  Future<int> getTotal(String name) {
    counter.putIfAbsent(name, () => 0);
    return Future.value(counter[name]);
  }

  @override
  Future increment(String name, {int increment = 1}) {
    counter.putIfAbsent(name, () => 0);
    return Future.value(counter[name]++);
  }

  void reset() => counter.clear();
}
