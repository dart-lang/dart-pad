// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api_test;

import 'dart:async';
import 'dart:convert';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/common_server_api.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:mock_request/mock_request.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

const versions = ['v1', 'v2'];

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
  CommonServerApi commonServerApi;
  CommonServerImpl commonServerImpl;
  FlutterWebManager flutterWebManager;

  MockContainer container;
  MockCache cache;

  Future<MockHttpResponse> _sendPostRequest(
    String path,
    dynamic jsonData,
  ) async {
    assert(commonServerApi != null);
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', JSON_CONTENT_TYPE);
    request.add(utf8.encode(json.encode(jsonData)));
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router.handler);
    return request.response;
  }

  Future<MockHttpResponse> _sendGetRequest(
    String path,
  ) async {
    assert(commonServerApi != null);
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', JSON_CONTENT_TYPE);
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router.handler);
    return request.response;
  }

  group('CommonServerProto JSON', () {
    setUpAll(() async {
      container = MockContainer();
      cache = MockCache();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);
      commonServerImpl =
          CommonServerImpl(sdkPath, flutterWebManager, container, cache);
      commonServerApi = CommonServerApi(commonServerImpl);
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
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response =
            await _sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {});
      }
    });

    test('analyze Flutter', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeFlutter};
        final response =
            await _sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyze errors', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeError};
        final response =
            await _sendPostRequest('dartservices/$version/analyze', jsonData);
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
      }
    });

    test('analyze negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = {};
        final response =
            await _sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('compile', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response =
            await _sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('compile error', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeError};
        final response =
            await _sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 400);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
        expect(data['error']['message'], contains('Error: Expected'));
      }
    });

    test('compile negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = {};
        final response =
            await _sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('compileDDC', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response = await _sendPostRequest(
            'dartservices/$version/compileDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('complete', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}', 'offset': 1};
        final response =
            await _sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('complete no data', () async {
      for (final version in versions) {
        final response =
            await _sendPostRequest('dartservices/$version/complete', {});
        expect(response.statusCode, 400);
      }
    });

    test('complete param missing', () async {
      for (final version in versions) {
        final jsonData = {'offset': 1};
        final response =
            await _sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('complete param missing 2', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}'};
        final response =
            await _sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 400);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data['error']['message'], 'Missing parameter: \'offset\'');
      }
    });

    test('document', () async {
      for (final version in versions) {
        final jsonData = {
          'source': 'void main() {print("foo");}',
          'offset': 17
        };
        final response =
            await _sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('document little data', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}', 'offset': 2};
        final response =
            await _sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {
          'info': {},
        });
      }
    });

    test('document no data', () async {
      for (final version in versions) {
        final jsonData = {
          'source': 'void main() {print("foo");}',
          'offset': 12
        };
        final response =
            await _sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {'info': {}});
      }
    });

    test('document negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = {'offset': 12};
        final response =
            await _sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('document negative-test noOffset', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}'};
        final response =
            await _sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('format', () async {
      for (final version in versions) {
        final jsonData = {'source': preFormattedCode};
        final response =
            await _sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data['newString'], postFormattedCode);
      }
    });

    test('format bad code', () async {
      for (final version in versions) {
        final jsonData = {'source': formatBadCode};
        final response =
            await _sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data['newString'], formatBadCode);
      }
    });

    test('format position', () async {
      for (final version in versions) {
        final jsonData = {'source': preFormattedCode, 'offset': 21};
        final response =
            await _sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data['newString'], postFormattedCode);
        expect(data['offset'], 24);
      }
    });

    test('fix', () async {
      for (final version in versions) {
        final jsonData = {'source': quickFixesCode, 'offset': 10};
        final response =
            await _sendPostRequest('dartservices/$version/fixes', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        final fixes = data['fixes'];
        expect(fixes.length, 1);
        final problemAndFix = fixes[0];
        expect(problemAndFix['problemMessage'], isNotNull);
      }
    });

    test('fixes completeness', () async {
      for (final version in versions) {
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
            await _sendPostRequest('dartservices/$version/fixes', jsonData);
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
      }
    });

    test('assist', () async {
      for (final version in versions) {
        final jsonData = {'source': assistCode, 'offset': 15};
        final response =
            await _sendPostRequest('dartservices/$version/assists', jsonData);
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
      }
    });

    test('version', () async {
      for (final version in versions) {
        final response = await _sendGetRequest('dartservices/$version/version');
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data['sdkVersion'], isNotNull);
        expect(data['runtimeVersion'], isNotNull);
      }
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
