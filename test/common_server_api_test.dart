// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_api_test;

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:angel3_mock_request/angel3_mock_request.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_api.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

const versions = ['v1', 'v2'];

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

void main() => defineTests();

void defineTests() {
  late CommonServerApi commonServerApi;
  late CommonServerImpl commonServerImpl;

  Future<MockHttpResponse> sendPostRequest(
    String path,
    dynamic jsonData,
  ) async {
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('POST', uri);
    request.headers.add('content-type', jsonContentType);
    request.add(utf8.encode(json.encode(jsonData)));
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router);
    return request.response;
  }

  Future<MockHttpResponse> sendGetRequest(
    String path,
  ) async {
    final uri = Uri.parse('/api/$path');
    final request = MockHttpRequest('GET', uri);
    request.headers.add('content-type', jsonContentType);
    await request.close();
    await shelf_io.handleRequest(request, commonServerApi.router);
    return request.response;
  }

  group('CommonServerProto JSON', () {
    final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;

    setUp(() async {
      final container = MockContainer();
      final cache = MockCache();
      final sdk = Sdk.create(channel);
      commonServerImpl = CommonServerImpl(container, cache, sdk);
      commonServerApi = CommonServerApi(commonServerImpl);
      await commonServerImpl.init();

      // Some piece of initialization doesn't always happen fast enough for this
      // request to work in time for the test. So try it here until the server
      // returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = <dynamic, dynamic>{};
        final jsonData = {'source': sampleCodeError};
        while (decodedJson.isEmpty) {
          final response =
              await sendPostRequest('dartservices/v2/analyze', jsonData);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'],
              ['application/json; charset=utf-8']);
          final data = await response.transform(utf8.decoder).join();
          decodedJson = json.decode(data) as Map<dynamic, dynamic>;
        }
      }
    });

    tearDown(() async {
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
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), <dynamic, dynamic>{});
      }
    });

    test('analyze Flutter', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeFlutter};
        final response =
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyze code with constructor-tearoffs features', () async {
      for (final version in versions) {
        final jsonData = {
          'source': '''
void main() {
  List<int>;
}
'''
        };
        final response =
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), <dynamic, dynamic>{});
      }
    },
        // TODO(srawlins): delete when channel `old` >= 2.15
        skip: channel == 'old');

    test('analyze counterApp', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeFlutterCounter};
        final response =
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyze draggableAndPhysicsApp', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeFlutterDraggableCard};
        final response =
            await sendPostRequest('dartservices/$version/analyze', jsonData);
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
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 200);
        expect(response.headers['content-type'],
            ['application/json; charset=utf-8']);
        final data = await response.transform(utf8.decoder).join();
        final dataMap = (json.decode(data) as Map).cast<String, Object>();
        expect(
          dataMap,
          {
            'issues': [
              {
                'kind': 'error',
                'line': 2,
                'sourceName': 'main.dart',
                'message': "Expected to find ';'.",
                'hasFixes': true,
                'charStart': 29,
                'charLength': 1,
              }
            ]
          },
        );
      }
    });

    test('analyze negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = <dynamic, dynamic>{};
        final response =
            await sendPostRequest('dartservices/$version/analyze', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('compile', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response =
            await sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('compile with cache', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response1 =
            await sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response1.statusCode, 200);
        final data1 = await response1.transform(utf8.decoder).join();
        expect(json.decode(data1), isNotEmpty);

        final response2 =
            await sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response2.statusCode, 200);
        final data2 = await response2.transform(utf8.decoder).join();
        expect(json.decode(data2), isNotEmpty);
      }
    });

    test('compile error', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCodeError};
        final response =
            await sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 400);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data, isNotEmpty);
        final error = data['error'] as Map<String, dynamic>;
        expect(error['message'], contains('Error: Expected'));
      }
    });

    test('compile negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = <dynamic, dynamic>{};
        final response =
            await sendPostRequest('dartservices/$version/compile', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('compileDDC', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response =
            await sendPostRequest('dartservices/$version/compileDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('compileDDC with cache', () async {
      for (final version in versions) {
        final jsonData = {'source': sampleCode};
        final response1 =
            await sendPostRequest('dartservices/$version/compileDDC', jsonData);
        expect(response1.statusCode, 200);
        final data1 = await response1.transform(utf8.decoder).join();
        expect(json.decode(data1), isNotEmpty);

        final response2 =
            await sendPostRequest('dartservices/$version/compileDDC', jsonData);
        expect(response2.statusCode, 200);
        final data2 = await response2.transform(utf8.decoder).join();
        expect(json.decode(data2), isNotEmpty);
      }
    });

    test('complete', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}', 'offset': 1};
        final response =
            await sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('complete no data', () async {
      for (final version in versions) {
        final response = await sendPostRequest(
            'dartservices/$version/complete', <dynamic, dynamic>{});
        expect(response.statusCode, 400);
      }
    });

    test('complete param missing', () async {
      for (final version in versions) {
        final jsonData = {'offset': 1};
        final response =
            await sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('complete param missing 2', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}'};
        final response =
            await sendPostRequest('dartservices/$version/complete', jsonData);
        expect(response.statusCode, 400);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final error = data['error'] as Map<String, dynamic>;
        expect(error['message'], 'Missing parameter: \'offset\'');
      }
    });

    test('document', () async {
      for (final version in versions) {
        final jsonData = {
          'source': 'void main() {print("foo");}',
          'offset': 17
        };
        final response =
            await sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('document little data', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}', 'offset': 2};
        final response =
            await sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {
          'info': <dynamic, dynamic>{},
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
            await sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {'info': <dynamic, dynamic>{}});
      }
    });

    test('document negative-test noSource', () async {
      for (final version in versions) {
        final jsonData = {'offset': 12};
        final response =
            await sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('document negative-test noOffset', () async {
      for (final version in versions) {
        final jsonData = {'source': 'void main() {print("foo");}'};
        final response =
            await sendPostRequest('dartservices/$version/document', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('format', () async {
      for (final version in versions) {
        final jsonData = {'source': preFormattedCode};
        final response =
            await sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data['newString'], postFormattedCode);
      }
    });

    test('format bad code', () async {
      for (final version in versions) {
        final jsonData = {'source': formatBadCode};
        final response =
            await sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data['newString'], formatBadCode);
      }
    });

    test('format position', () async {
      for (final version in versions) {
        final jsonData = {'source': preFormattedCode, 'offset': 21};
        final response =
            await sendPostRequest('dartservices/$version/format', jsonData);
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data['newString'], postFormattedCode);
        expect(data['offset'], 24);
      }
    });

    test('fix', () async {
      final quickFixesCode = '''
import 'dart:async';
void main() {
  int i = 0;
}
''';
      for (final version in versions) {
        final jsonData = {'source': quickFixesCode, 'offset': 10};
        final response =
            await sendPostRequest('dartservices/$version/fixes', jsonData);
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final fixes = data['fixes'] as List<dynamic>;
        expect(fixes.length, 1);
        final problemAndFix = fixes[0] as Map<String, dynamic>;
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
            await sendPostRequest('dartservices/$version/fixes', jsonData);
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
      final assistCode = '''
main() {
  int v = 0;
}
''';
      for (final version in versions) {
        final jsonData = {'source': assistCode, 'offset': 15};
        final response =
            await sendPostRequest('dartservices/$version/assists', jsonData);
        expect(response.statusCode, 200);

        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final assists = data['assists'] as List<dynamic>;
        expect(assists, hasLength(2));
        final firstEdit = assists.first as Map<String, dynamic>;
        expect(firstEdit['edits'], isNotNull);
        expect(firstEdit['edits'], hasLength(1));
        expect(assists.where((m) {
          final map = m as Map<String, dynamic>;
          return map['message'] == 'Remove type annotation';
        }), isNotEmpty);
      }
    });

    test('version', () async {
      for (final version in versions) {
        final response = await sendGetRequest('dartservices/$version/version');
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data['sdkVersion'], isNotNull);
        expect(data['runtimeVersion'], isNotNull);
      }
    });
  });

  //-------------------------------------------------------------------------
  // Beginning of multi file files={} tests group:
  group('CommonServerProto JSON for Multi file group files={}', () {
    final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;

    setUp(() async {
      final container = MockContainer();
      final cache = MockCache();
      final sdk = Sdk.create(channel);
      commonServerImpl = CommonServerImpl(container, cache, sdk);
      commonServerApi = CommonServerApi(commonServerImpl);
      await commonServerImpl.init();

      // Some piece of initialization doesn't always happen fast enough for this
      // request to work in time for the test. So try it here until the server
      // returns something valid.
      // TODO(jcollins-g): determine which piece of initialization isn't
      // happening and deal with that in warmup/init.
      {
        var decodedJson = <dynamic, dynamic>{};
        final jsonData = {'source': sampleCodeError};
        while (decodedJson.isEmpty) {
          final response =
              await sendPostRequest('dartservices/v2/analyze', jsonData);
          expect(response.statusCode, 200);
          expect(response.headers['content-type'],
              ['application/json; charset=utf-8']);
          final data = await response.transform(utf8.decoder).join();
          decodedJson = json.decode(data) as Map<dynamic, dynamic>;
        }
      }
    });

    tearDown(() async {
      await commonServerImpl.shutdown();
    });

    setUp(() {
      log.onRecord.listen((LogRecord rec) {
        print('${rec.level.name}: ${rec.time}: ${rec.message}');
      });
    });

    tearDown(log.clearListeners);

    test('analyzeFiles Dart files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCode}
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), <dynamic, dynamic>{});
      }
    });

    test('analyzeFiles Flutter files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeFlutter}
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyzeFiles code with constructor-tearoffs features files={}',
        () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: '''
void main() {
  List<int>;
}
'''
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), <dynamic, dynamic>{});
      }
    },
        // TODO(srawlins): delete when channel `old` >= 2.15
        skip: channel == 'old');

    test('analyzeFiles counterApp files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeFlutterCounter}
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyzeFiles draggableAndPhysicsApp files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeFlutterDraggableCard}
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), {
          'packageImports': ['flutter']
        });
      }
    });

    test('analyzeFiles errors files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeError}
        };
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 200);
        expect(response.headers['content-type'],
            ['application/json; charset=utf-8']);
        final data = await response.transform(utf8.decoder).join();
        final dataMap = (json.decode(data) as Map).cast<String, Object>();
        expect(
          dataMap,
          {
            'issues': [
              {
                'kind': 'error',
                'line': 2,
                'sourceName': 'main.dart',
                'message': "Expected to find ';'.",
                'hasFixes': true,
                'charStart': 29,
                'charLength': 1,
              }
            ]
          },
        );
      }
    });

    test('analyzeFiles negative-test noFiles files={}', () async {
      for (final version in versions) {
        final jsonData = <dynamic, dynamic>{};
        final response = await sendPostRequest(
            'dartservices/$version/analyzeFiles', jsonData);
        expect(response.statusCode, 400);
      }
    });

    // Begin compileFiles entry point testing:
    test('compileFiles files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCode}
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 separate files, main importing 'various.dart'.
    test('compileFiles files={} with 2 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCodeMultiFoo,
            'bar.dart': sampleCodeMultiBar,
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 separate files, main importing 'various.dart' but with
    // up paths in names... test sanitizing filenames of '..\.../..' and '..'
    // santizing should strip off all up dir chars and leave just the
    // plain filenames.
    test('compileFiles files={} with 2 files using import need sanitizing',
        () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            '..\\.../../$kMainDart': sampleCodeMultiFoo,
            '../bar.dart': sampleCodeMultiBar
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 files using "part 'bar.dart'" to bring in second file.
    test('compileFiles files={} with 2 files using library/part', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCodeLibraryMultiFoo,
            'bar.dart': sampleCodePartMultiBar
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('compileFiles with cache files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCode}
        };
        final response1 = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response1.statusCode, 200);
        final data1 = await response1.transform(utf8.decoder).join();
        expect(json.decode(data1), isNotEmpty);

        final response2 = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response2.statusCode, 200);
        final data2 = await response2.transform(utf8.decoder).join();
        expect(json.decode(data2), isNotEmpty);
      }
    });

    test('compileFiles error files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeError}
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 400);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data, isNotEmpty);
        final error = data['error'] as Map<String, dynamic>;
        expect(error['message'], contains('Error: Expected'));
      }
    });

    test('compileFiles negative-test noFiles files={}', () async {
      for (final version in versions) {
        final jsonData = <dynamic, dynamic>{};
        final response = await sendPostRequest(
            'dartservices/$version/compileFiles', jsonData);
        expect(response.statusCode, 400);
      }
    });

    // Begin compileFilesDDC entry point testing DDC testing:
    test('compileFilesDDC files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCode}
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 separate files, main importing 'various.dart'.
    test('compileFilesDDC files={} with 2 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCode2PartImportMain,
            'various.dart': sampleCode2PartImportVarious
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 3 separate files, main importing 'various.dart' and 'discdata.dart'.
    test('compileFilesDDC files={} with 3 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCode3PartImportMain,
            'discdata.dart': sampleCode3PartImportDiscData,
            'various.dart': sampleCode3PartImportVarious
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 separate files, main importing 'various.dart' but with
    // up paths in names... test sanitizing filenames of '..\.../..' and '..'
    // santizing should strip off all up dir chars and leave just the
    // plain filenames.
    test('compileFilesDDC files={} with 2 files using import need sanitizing',
        () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            '..\\.../../$kMainDart': sampleCode2PartImportMain,
            '../various.dart': sampleCode2PartImportVarious
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 2 files using "part 'various.dart'" to bring in second file.
    test('compileFilesDDC files={} with 2 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCode2PartImportMain,
            'various.dart': sampleCode2PartImportVarious
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // 3 files using "part 'various.dart'" and "part 'discdata.dart'" to bring
    // in second and third files.
    test('compileFilesDDC files={} with 3 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCode3PartLibraryMain,
            'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
            'various.dart': sampleCode3PartVariousPartOfTestAnim,
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // Check sanitizing of package:, dart:, http:// from filenames.
    test('compileFilesDDC files={} with 3 files using import needs sanitizing',
        () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            'package:$kMainDart': sampleCode3PartLibraryMain,
            'dart:discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
            'http://various.dart': sampleCode3PartVariousPartOfTestAnim,
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    // Test renaming the file with the main function ('mymain.dart') to be
    // kMainDart when no file named kMainDart is found.
    test('compileFilesDDC files={} with 3 files using import', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
            'various.dart': sampleCode3PartVariousPartOfTestAnim,
            'mymain.dart': sampleCode3PartLibraryMain
          }
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 200);
        final data = await response.transform(utf8.decoder).join();
        expect(json.decode(data), isNotEmpty);
      }
    });

    test('compileFilesDDC with cache files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCode}
        };
        final response1 = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response1.statusCode, 200);
        final data1 = await response1.transform(utf8.decoder).join();
        expect(json.decode(data1), isNotEmpty);

        final response2 = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response2.statusCode, 200);
        final data2 = await response2.transform(utf8.decoder).join();
        expect(json.decode(data2), isNotEmpty);
      }
    });

    test('compileFilesDDC 3 files set with cache files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: sampleCode3PartLibraryMain,
            'discdata.dart': sampleCode3PartDiscDataPartOfTestAnim,
            'various.dart': sampleCode3PartVariousPartOfTestAnim
          }
        };
        final response1 = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response1.statusCode, 200);
        final data1 = await response1.transform(utf8.decoder).join();
        expect(json.decode(data1), isNotEmpty);

        final response2 = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response2.statusCode, 200);
        final data2 = await response2.transform(utf8.decoder).join();
        expect(json.decode(data2), isNotEmpty);
      }
    });

    test('compileFilesDDC error files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: sampleCodeError}
        };
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 400);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        expect(data, isNotEmpty);
        final error = data['error'] as Map<String, dynamic>;
        expect(error['message'], contains('Error: Expected'));
      }
    });

    test('compileFilesDDC negative-test noFiles files={}', () async {
      for (final version in versions) {
        final jsonData = <dynamic, dynamic>{};
        final response = await sendPostRequest(
            'dartservices/$version/compileFilesDDC', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('completeFiles files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'},
          'activeSourceName': kMainDart,
          'offset': 1
        };
        final response = await sendPostRequest(
            'dartservices/$version/completeFiles', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('completeFiles no data files={}', () async {
      for (final version in versions) {
        final response = await sendPostRequest(
            'dartservices/$version/completeFiles', <dynamic, dynamic>{});
        expect(response.statusCode, 400);
      }
    });

    test('completeFiles param missing files={}', () async {
      for (final version in versions) {
        final jsonData = {'offset': 1};
        final response = await sendPostRequest(
            'dartservices/$version/completeFiles', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('completeFiles param missing 2 files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'}
        };
        final response = await sendPostRequest(
            'dartservices/$version/completeFiles', jsonData);
        expect(response.statusCode, 400);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final error = data['error'] as Map<String, dynamic>;
        expect(error['message'], 'Missing parameter: \'activeSourceName\'');
      }
    });

    test('documentFiles files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'},
          'activeSourceName': kMainDart,
          'offset': 17
        };
        final response = await sendPostRequest(
            'dartservices/$version/documentFiles', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, isNotEmpty);
      }
    });

    test('documentFiles little data files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'},
          'activeSourceName': kMainDart,
          'offset': 2
        };
        final response = await sendPostRequest(
            'dartservices/$version/documentFiles', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {
          'info': <dynamic, dynamic>{},
        });
      }
    });

    test('documentFiles no data files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'},
          'activeSourceName': kMainDart,
          'offset': 12
        };
        final response = await sendPostRequest(
            'dartservices/$version/documentFiles', jsonData);
        expect(response.statusCode, 200);
        final data = json.decode(await response.transform(utf8.decoder).join());
        expect(data, {'info': <dynamic, dynamic>{}});
      }
    });

    test('documentFiles negative-test noFiles files={}', () async {
      for (final version in versions) {
        final jsonData = {'offset': 12};
        final response = await sendPostRequest(
            'dartservices/$version/documentFiles', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('documentFiles negative-test noActiveSourceName/noOffset files={}',
        () async {
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: 'void main() {print("foo");}'}
        };
        final response = await sendPostRequest(
            'dartservices/$version/documentFiles', jsonData);
        expect(response.statusCode, 400);
      }
    });

    test('fix2 files={}', () async {
      final quickFixesCode = '''
import 'dart:async';
void main() {
  int i = 0;
}
''';
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: quickFixesCode},
          'activeSourceName': kMainDart,
          'offset': 10
        };
        final response =
            await sendPostRequest('dartservices/$version/fixesFiles', jsonData);
        expect(response.statusCode, 200);
        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final fixes = data['fixes'] as List<dynamic>;
        expect(fixes.length, 1);
        final problemAndFix = fixes[0] as Map<String, dynamic>;
        expect(problemAndFix['problemMessage'], isNotNull);
      }
    });

    test('fixesFiles completeness files={}', () async {
      for (final version in versions) {
        final jsonData = {
          'files': {
            kMainDart: '''
void main() {
  for (int i = 0; i < 4; i++) {
    print('hello \$i')
  }
}
'''
          },
          'activeSourceName': kMainDart,
          'offset': 67,
        };
        final response =
            await sendPostRequest('dartservices/$version/fixesFiles', jsonData);
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

    test('assist2 files={}', () async {
      final assistCode = '''
main() {
  int v = 0;
}
''';
      for (final version in versions) {
        final jsonData = {
          'files': {kMainDart: assistCode},
          'activeSourceName': kMainDart,
          'offset': 15
        };
        final response = await sendPostRequest(
            'dartservices/$version/assistsFiles', jsonData);
        expect(response.statusCode, 200);

        final encoded = await response.transform(utf8.decoder).join();
        final data = json.decode(encoded) as Map<String, dynamic>;
        final assists = data['assists'] as List<dynamic>;
        expect(assists, hasLength(2));
        final firstEdit = assists.first as Map<String, dynamic>;
        expect(firstEdit['edits'], isNotNull);
        expect(firstEdit['edits'], hasLength(1));
        expect(assists.where((m) {
          final map = m as Map<String, dynamic>;
          return map['message'] == 'Remove type annotation';
        }), isNotEmpty);
      }
    });
  });
  // End of multi file files={} tests group.
  //-------------------------------------------------------------------------
}

class MockContainer implements ServerContainer {
  @override
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  final _cache = HashMap<String, String>();

  @override
  Future<String?> get(String key) async => _cache[key];

  @override
  Future<void> set(String key, String value, {Duration? expiration}) async =>
      _cache[key] = value;

  @override
  Future<void> remove(String key) async => _cache.remove(key);

  @override
  Future<void> shutdown() async => _cache.removeWhere((key, value) => true);
}
