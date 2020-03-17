// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api_v1_test;

import 'dart:async';
import 'dart:convert';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:rpc/rpc.dart';
import 'package:test/test.dart';

const quickFixesCode = r'''
import 'dart:async';
void main() {
  int i = 0;
}
''';

const preFormattedCode = r'''
void main()
{
int i = 0;
}
''';

const postFormattedCode = r'''
void main() {
  int i = 0;
}
''';

const formatBadCode = r'''
void main()
{
  print('foo')
}
''';

const assistCode = r'''
main() {
  int v = 0;
}
''';

void main() => defineTests();

void defineTests() {
  CommonServer server;
  CommonServerImpl commonServerImpl;
  ApiServer apiServer;
  FlutterWebManager flutterWebManager;

  MockContainer container;
  MockCache cache;

  Future<HttpApiResponse> _sendPostRequest(String path, jsonData) {
    assert(apiServer != null);
    final uri = Uri.parse('/api/$path');
    final body = Stream.fromIterable([utf8.encode(json.encode(jsonData))]);
    final request = HttpApiRequest(
        'POST', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  Future<HttpApiResponse> _sendGetRequest(String path, [String queryParams]) {
    assert(apiServer != null);
    final uri = Uri.parse(
        queryParams == null ? '/api/$path' : '/api/$path?$queryParams');
    final body = Stream<List<int>>.fromIterable([]);
    final request = HttpApiRequest(
        'GET', uri, {'content-type': 'application/json; charset=utf-8'}, body);
    return apiServer.handleHttpApiRequest(request);
  }

  group('CommonServer', () {
    setUpAll(() async {
      container = MockContainer();
      cache = MockCache();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      commonServerImpl =
          CommonServerImpl(sdkPath, flutterWebManager, container, cache);
      server = CommonServer(commonServerImpl);
      await commonServerImpl.init();

      apiServer = ApiServer(apiPrefix: '/api', prettyPrint: true);
      apiServer.addApi(server);

      // Some piece of initialization doesn't always happen fast enough for this
      // request to work in time for the test. So try it here until the server
      // returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = {};
        final jsonData = {'source': sampleCodeError};
        while (decodedJson.isEmpty) {
          final response =
              await _sendPostRequest('dartservices/v1/analyze', jsonData);
          expect(response.status, 200);
          expect(response.headers['content-type'],
              'application/json; charset=utf-8');
          final data = await response.body.first;
          decodedJson = json.decode(utf8.decode(data)) as Map<dynamic, dynamic>;
        }
      }
    });

    tearDownAll(() async {
      await commonServerImpl.shutdown();
    });

    setUp(() {
      log.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    });

    tearDown(log.clearListeners);

    test('analyze Dart', () async {
      final jsonData = {'source': sampleCode};
      final response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 200);
      final data = await response.body.first;
      expect(
          json.decode(utf8.decode(data)), {'issues': [], 'packageImports': []});
    });

    test('analyze Flutter', () async {
      final jsonData = {'source': sampleCodeFlutter};
      final response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 200);
      final data = await response.body.first;
      expect(json.decode(utf8.decode(data)), {
        'issues': [],
        'packageImports': ['flutter']
      });
    });

    test('analyze errors', () async {
      final jsonData = {'source': sampleCodeError};
      final response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 200);
      expect(
          response.headers['content-type'], 'application/json; charset=utf-8');
      final data = await response.body.first;
      final expectedJson = {
        'issues': [
          {
            'kind': 'error',
            'line': 2,
            'sourceName': 'main.dart',
            'message': "Expected to find ';'.",
            'hasFixes': true,
            'charStart': 29,
            'charLength': 1
          }
        ],
        'packageImports': []
      };
      expect(json.decode(utf8.decode(data)), expectedJson);
    });

    test('analyze negative-test noSource', () async {
      final jsonData = {};
      final response =
          await _sendPostRequest('dartservices/v1/analyze', jsonData);
      expect(response.status, 400);
    });

    test('compile', () async {
      final jsonData = {'source': sampleCode};
      final response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 200);
      final data = await response.body.first;
      expect(json.decode(utf8.decode(data)), isNotEmpty);
    });

    test('compile error', () async {
      final jsonData = {'source': sampleCodeError};
      final response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 400);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
      expect(data['error']['message'], contains('Error: Expected'));
    });

    test('compile negative-test noSource', () async {
      final jsonData = {};
      final response =
          await _sendPostRequest('dartservices/v1/compile', jsonData);
      expect(response.status, 400);
    });

    test('compileDDC', () async {
      final jsonData = {'source': sampleCode};
      final response =
          await _sendPostRequest('dartservices/v1/compileDDC', jsonData);
      expect(response.status, 200);
      final data = await response.body.first;
      expect(json.decode(utf8.decode(data)), isNotEmpty);
    });

    test('complete', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 1};
      final response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('complete no data', () async {
      final response = await _sendPostRequest('dartservices/v1/complete', {});
      expect(response.status, 400);
    });

    test('complete param missing', () async {
      final jsonData = {'offset': 1};
      final response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 400);
    });

    test('complete param missing 2', () async {
      final jsonData = {'source': 'void main() {print("foo");}'};
      final response =
          await _sendPostRequest('dartservices/v1/complete', jsonData);
      expect(response.status, 400);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 17};
      final response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 2};
      final response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, {
        'info': {},
      });
    });

    test('document no data', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 12};
      final response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, {'info': {}});
    });

    test('document negative-test noSource', () async {
      final jsonData = {'offset': 12};
      final response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 400);
    });

    test('document negative-test noOffset', () async {
      final jsonData = {'source': 'void main() {print("foo");}'};
      final response =
          await _sendPostRequest('dartservices/v1/document', jsonData);
      expect(response.status, 400);
    });

    test('format', () async {
      final jsonData = {'source': preFormattedCode};
      final response =
          await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data['newString'], postFormattedCode);
    });

    test('format bad code', () async {
      final jsonData = {'source': formatBadCode};
      final response =
          await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data['newString'], formatBadCode);
    });

    test('format position', () async {
      final jsonData = {'source': preFormattedCode, 'offset': 21};
      final response =
          await _sendPostRequest('dartservices/v1/format', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data['newString'], postFormattedCode);
      expect(data['offset'], 24);
    });

    test('fix', () async {
      final jsonData = {'source': quickFixesCode, 'offset': 10};
      final response =
          await _sendPostRequest('dartservices/v1/fixes', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      final fixes = data['fixes'];
      expect(fixes.length, 1);
      final problemAndFix = fixes[0];
      expect(problemAndFix['problemMessage'], isNotNull);
    });

    test('fixes completeness', () async {
      final jsonData = {
        'source': '''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello \$i')
  }
}
''',
        'offset': 67,
      };
      final response =
          await _sendPostRequest('dartservices/v1/fixes', jsonData);
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data, {
        'fixes': [
          {
            'fixes': [
              {
                'message': "Insert ';'",
                'edits': [
                  {'offset': 67, 'length': 0, 'replacement': ';'}
                ]
              }
            ],
            'problemMessage': "Expected to find ';'.",
            'offset': 66,
            'length': 1
          }
        ]
      });
    });

    test('assist', () async {
      final jsonData = {'source': assistCode, 'offset': 15};
      final response =
          await _sendPostRequest('dartservices/v1/assists', jsonData);
      expect(response.status, 200);

      final data = json.decode(utf8.decode(await response.body.first));
      final assists = data['assists'] as List;
      expect(assists, hasLength(2));
      expect(assists.first['edits'], isNotNull);
      expect(assists.first['edits'], hasLength(1));
      expect(assists.where((m) {
        final map = m as Map<String, dynamic>;
        return map['message'] == 'Remove type annotation';
      }), isNotEmpty);
    });

    test('version', () async {
      final response = await _sendGetRequest('dartservices/v1/version');
      expect(response.status, 200);
      final data = json.decode(utf8.decode(await response.body.first));
      expect(data['sdkVersion'], isNotNull);
      expect(data['runtimeVersion'], isNotNull);
    });
  });
}

class MockContainer implements ServerContainer {
  @override
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  @override
  Future<String> get(String key) => Future.value(null);

  @override
  Future set(String key, String value, {Duration expiration}) => Future.value();

  @override
  Future remove(String key) => Future.value();

  @override
  Future<void> shutdown() => Future.value();
}
