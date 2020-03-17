// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api_v2_test;

import 'dart:async';
import 'dart:convert';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/common_server_proto.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:mock_request/mock_request.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
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
  CommonServerProto commonServerProto;
  CommonServerImpl commonServerImpl;
  FlutterWebManager flutterWebManager;

  MockContainer container;
  MockCache cache;

  Future<MockHttpResponse> _sendPostRequest(
    String path,
    dynamic jsonData,
  ) async {
    assert(commonServerProto != null);
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', JSON_CONTENT_TYPE);
    request.add(utf8.encode(json.encode(jsonData)));
    await request.close();
    await shelf_io.handleRequest(request, commonServerProto.router.handler);
    return request.response;
  }

  Future<MockHttpResponse> _sendGetRequest(
    String path,
  ) async {
    assert(commonServerProto != null);
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', JSON_CONTENT_TYPE);
    await request.close();
    await shelf_io.handleRequest(request, commonServerProto.router.handler);
    return request.response;
  }

  group('CommonServerProto JSON', () {
    setUpAll(() async {
      container = MockContainer();
      cache = MockCache();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      commonServerImpl =
          CommonServerImpl(sdkPath, flutterWebManager, container, cache);
      commonServerProto = CommonServerProto(commonServerImpl);
      await commonServerImpl.init();

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
              await _sendPostRequest('dartservices/v2/analyze', jsonData);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'],
              ['application/json; charset=utf-8']);
          final data = await response.transform(utf8.decoder).join();
          decodedJson = json.decode(data) as Map<dynamic, dynamic>;
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
          await _sendPostRequest('dartservices/v2/analyze', jsonData);
      expect(response.statusCode, 200);
      final data = await response.transform(utf8.decoder).join();
      expect(json.decode(data), {});
    });

    test('analyze Flutter', () async {
      final jsonData = {'source': sampleCodeFlutter};
      final response =
          await _sendPostRequest('dartservices/v2/analyze', jsonData);
      expect(response.statusCode, 200);
      final data = await response.transform(utf8.decoder).join();
      expect(json.decode(data), {
        'packageImports': ['flutter']
      });
    });

    test('analyze errors', () async {
      final jsonData = {'source': sampleCodeError};
      final response =
          await _sendPostRequest('dartservices/v2/analyze', jsonData);
      expect(response.statusCode, 200);
      expect(response.headers['content-type'],
          ['application/json; charset=utf-8']);
      final data = await response.transform(utf8.decoder).join();
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
        ]
      };
      expect(json.decode(data), expectedJson);
    });

    test('analyze negative-test noSource', () async {
      final jsonData = {};
      final response =
          await _sendPostRequest('dartservices/v2/analyze', jsonData);
      expect(response.statusCode, 400);
    });

    test('compile', () async {
      final jsonData = {'source': sampleCode};
      final response =
          await _sendPostRequest('dartservices/v2/compile', jsonData);
      expect(response.statusCode, 200);
      final data = await response.transform(utf8.decoder).join();
      expect(json.decode(data), isNotEmpty);
    });

    test('compile error', () async {
      final jsonData = {'source': sampleCodeError};
      final response =
          await _sendPostRequest('dartservices/v2/compile', jsonData);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data, isNotEmpty);
      expect(data['error']['message'], contains('Error: Expected'));
    });

    test('compile negative-test noSource', () async {
      final jsonData = {};
      final response =
          await _sendPostRequest('dartservices/v2/compile', jsonData);
      expect(response.statusCode, 400);
    });

    test('compileDDC', () async {
      final jsonData = {'source': sampleCode};
      final response =
          await _sendPostRequest('dartservices/v2/compileDDC', jsonData);
      expect(response.statusCode, 200);
      final data = await response.transform(utf8.decoder).join();
      expect(json.decode(data), isNotEmpty);
    });

    test('complete', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 1};
      final response =
          await _sendPostRequest('dartservices/v2/complete', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data, isNotEmpty);
    });

    test('complete no data', () async {
      final response = await _sendPostRequest('dartservices/v2/complete', {});
      expect(response.statusCode, 400);
    });

    test('complete param missing', () async {
      final jsonData = {'offset': 1};
      final response =
          await _sendPostRequest('dartservices/v2/complete', jsonData);
      expect(response.statusCode, 400);
    });

    test('complete param missing 2', () async {
      final jsonData = {'source': 'void main() {print("foo");}'};
      final response =
          await _sendPostRequest('dartservices/v2/complete', jsonData);
      expect(response.statusCode, 400);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data['error']['message'], 'Missing parameter: \'offset\'');
    });

    test('document', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 17};
      final response =
          await _sendPostRequest('dartservices/v2/document', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data, isNotEmpty);
    });

    test('document little data', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 2};
      final response =
          await _sendPostRequest('dartservices/v2/document', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data, {
        'info': {},
      });
    });

    test('document no data', () async {
      final jsonData = {'source': 'void main() {print("foo");}', 'offset': 12};
      final response =
          await _sendPostRequest('dartservices/v2/document', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data, {'info': {}});
    });

    test('document negative-test noSource', () async {
      final jsonData = {'offset': 12};
      final response =
          await _sendPostRequest('dartservices/v2/document', jsonData);
      expect(response.statusCode, 400);
    });

    test('document negative-test noOffset', () async {
      final jsonData = {'source': 'void main() {print("foo");}'};
      final response =
          await _sendPostRequest('dartservices/v2/document', jsonData);
      expect(response.statusCode, 400);
    });

    test('format', () async {
      final jsonData = {'source': preFormattedCode};
      final response =
          await _sendPostRequest('dartservices/v2/format', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data['newString'], postFormattedCode);
    });

    test('format bad code', () async {
      final jsonData = {'source': formatBadCode};
      final response =
          await _sendPostRequest('dartservices/v2/format', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data['newString'], formatBadCode);
    });

    test('format position', () async {
      final jsonData = {'source': preFormattedCode, 'offset': 21};
      final response =
          await _sendPostRequest('dartservices/v2/format', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
      expect(data['newString'], postFormattedCode);
      expect(data['offset'], 24);
    });

    test('fix', () async {
      final jsonData = {'source': quickFixesCode, 'offset': 10};
      final response =
          await _sendPostRequest('dartservices/v2/fixes', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
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
          await _sendPostRequest('dartservices/v2/fixes', jsonData);
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
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
          await _sendPostRequest('dartservices/v2/assists', jsonData);
      expect(response.statusCode, 200);

      final data = json.decode(await response.transform(utf8.decoder).join());
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
      final response = await _sendGetRequest('dartservices/v2/version');
      expect(response.statusCode, 200);
      final data = json.decode(await response.transform(utf8.decoder).join());
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
