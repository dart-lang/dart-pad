// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server.dart';
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:rpc/rpc.dart';
import 'package:synchronized/synchronized.dart';
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

  /// Integration tests for the RedisCache implementation.
  ///
  /// We basically assume that redis and dartis work correctly -- this is
  /// exercising the connection maintenance and exception handling.
  group('RedisCache', () {
    // Note: all caches share values between them.
    RedisCache redisCache, redisCacheAlt;
    Process redisProcess, redisAltProcess;
    var logMessages = <String>[];
    // Critical section handling -- do not run more than one test at a time
    // since they talk to the same redis instances.
    final singleTestOnly = Lock();

    // Prevent cases where we might try to reenter addStream for either stdout
    // or stderr (which will throw a BadState).
    final singleStreamOnly = Lock();

    Future<Process> startRedisProcessAndDrainIO(int port) async {
      final newRedisProcess =
          await Process.start('redis-server', ['--port', port.toString()]);
      unawaited(singleStreamOnly.synchronized(() async {
        await stdout.addStream(newRedisProcess.stdout);
      }));
      unawaited(singleStreamOnly.synchronized(() async {
        await stderr.addStream(newRedisProcess.stderr);
      }));
      return newRedisProcess;
    }

    setUpAll(() async {
      await SdkManager.sdk.init();
      redisProcess = await startRedisProcessAndDrainIO(9501);
      log.onRecord.listen((LogRecord rec) {
        logMessages.add('${rec.level.name}: ${rec.time}: ${rec.message}');
        print(logMessages.last);
      });
      redisCache = RedisCache('redis://localhost:9501', 'aversion');
      redisCacheAlt = RedisCache('redis://localhost:9501', 'bversion');
      await Future.wait([redisCache.connected, redisCacheAlt.connected]);
    });

    tearDown(() async {
      if (redisAltProcess != null) {
        redisAltProcess.kill();
        await redisAltProcess.exitCode;
        redisAltProcess = null;
      }
    });

    tearDownAll(() async {
      log.clearListeners();
      await Future.wait([redisCache.shutdown(), redisCacheAlt.shutdown()]);
      redisProcess.kill();
      await redisProcess.exitCode;
    });

    test('Verify basic operation of RedisCache', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await expectLater(await redisCache.get('unknownkey'), isNull);
        await redisCache.set('unknownkey', 'value');
        await expectLater(await redisCache.get('unknownkey'), equals('value'));
        await redisCache.remove('unknownkey');
        await expectLater(await redisCache.get('unknownkey'), isNull);
        expect(logMessages, isEmpty);
      });
    });

    test('Verify values expire', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await redisCache.set('expiringkey', 'expiringValue',
            expiration: Duration(milliseconds: 1));
        await Future.delayed(Duration(milliseconds: 100));
        await expectLater(await redisCache.get('expiringkey'), isNull);
        expect(logMessages, isEmpty);
      });
    });

    test(
        'Verify two caches with different versions give different results for keys',
        () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await redisCache.set('differentVersionKey', 'value1');
        await redisCacheAlt.set('differentVersionKey', 'value2');
        await expectLater(
            await redisCache.get('differentVersionKey'), 'value1');
        await expectLater(
            await redisCacheAlt.get('differentVersionKey'), 'value2');
        expect(logMessages, isEmpty);
      });
    });

    test('Verify disconnected cache logs errors and returns nulls', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        final redisCacheBroken =
            RedisCache('redis://localhost:9502', 'cversion');
        try {
          await redisCacheBroken.set('aKey', 'value');
          await expectLater(await redisCacheBroken.get('aKey'), isNull);
          await redisCacheBroken.remove('aKey');
          expect(
              logMessages.join('\n'),
              stringContainsInOrder([
                'no cache available when setting key server:cversion:dart:',
                '+aKey',
                'no cache available when getting key server:cversion:dart:',
                '+aKey',
                'no cache available when removing key server:cversion:dart:',
                '+aKey',
              ]));
        } finally {
          await redisCacheBroken.shutdown();
        }
      });
    });

    test('Verify cache that starts out disconnected retries and works (slow)',
        () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        final redisCacheRepairable =
            RedisCache('redis://localhost:9503', 'cversion');
        try {
          // Wait for a retry message.
          while (logMessages.length < 2) {
            await (Future.delayed(Duration(milliseconds: 50)));
          }
          expect(
              logMessages.join('\n'),
              stringContainsInOrder([
                'reconnecting to redis://localhost:9503...\n',
                'Unable to connect to redis server, reconnecting in',
              ]));

          // Start a redis server.
          redisAltProcess = await startRedisProcessAndDrainIO(9503);

          // Wait for connection.
          await redisCacheRepairable.connected;
          expect(logMessages.join('\n'), contains('Connected to redis server'));
        } finally {
          await redisCacheRepairable.shutdown();
        }
      });
    });

    test(
        'Verify that cache that stops responding temporarily times out and can recover',
        () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await redisCache.set('beforeStop', 'truth');
        redisProcess.kill(ProcessSignal.sigstop);
        // Don't fail the test before sending sigcont.
        final beforeStop = await redisCache.get('beforeStop');
        await redisCache.disconnected;
        redisProcess.kill(ProcessSignal.sigcont);
        expect(beforeStop, isNull);
        await redisCache.connected;
        await expectLater(await redisCache.get('beforeStop'), equals('truth'));
        expect(
            logMessages.join('\n'),
            stringContainsInOrder([
              'timeout on get operation for key server:aversion:dart:',
              '+beforeStop',
              '(aversion): reconnecting',
              '(aversion): Connected to redis server',
            ]));
      });
    }, onPlatform: {'windows': Skip('Windows does not have sigstop/sigcont')});

    test(
        'Verify cache that starts out connected but breaks retries until reconnection (slow)',
        () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];

        redisAltProcess = await startRedisProcessAndDrainIO(9504);
        final redisCacheHealing =
            RedisCache('redis://localhost:9504', 'cversion');
        try {
          await redisCacheHealing.connected;
          await redisCacheHealing.set('missingKey', 'value');
          // Kill process out from under the cache.
          redisAltProcess.kill();
          await redisAltProcess.exitCode;
          redisAltProcess = null;

          // Try to talk to the cache and get an error. Wait for the disconnect
          // to be recognized.
          await expectLater(await redisCacheHealing.get('missingKey'), isNull);
          await redisCacheHealing.disconnected;

          // Start the server and verify we connect appropriately.
          redisAltProcess = await startRedisProcessAndDrainIO(9504);
          await redisCacheHealing.connected;
          expect(
              logMessages.join('\n'),
              stringContainsInOrder([
                'Connected to redis server',
                'connection terminated with error SocketException',
                'reconnecting to redis://localhost:9504',
              ]));
          expect(logMessages.last, contains('Connected to redis server'));
        } finally {
          await redisCacheHealing.shutdown();
        }
      });
    });
  });

  group('CommonServer', () {
    setUpAll(() async {
      container = MockContainer();
      cache = MockCache();
      flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);

      server = CommonServer(sdkPath, flutterWebManager, container, cache);
      await server.init();

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
      await server.shutdown();
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
