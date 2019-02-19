// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.common_server_test;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:synchronized/synchronized.dart';
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

  /// Integration tests for the RedisCache implementation.
  ///
  /// We basically assume that redis and dartis work correctly -- this is
  /// exercising the connection maintenance and exception handling.
  group('RedisCache', () {
    // Note: all caches share values between them.
    RedisCache redisCache, redisCacheAlt;
    Process redisProcess, redisAltProcess;
    List<String> logMessages = [];
    // Critical section handling -- do not run more than one test at a time
    // since they talk to the same redis instances.
    Lock singleTestOnly = Lock();

    // Prevent cases where we might try to reenter addStream for either
    // stdout or stderr (which will throw a BadState).
    Lock singleStreamOnly = Lock();

    Future<Process> startRedisProcessAndDrainIO(int port) async {
      Process newRedisProcess = await Process.start('redis-server', ['--port', port.toString()]);
      unawaited(singleStreamOnly.synchronized(() async {
        await stdout.addStream(newRedisProcess.stdout);
      }));
      unawaited(singleStreamOnly.synchronized(() async {
        await stderr.addStream(newRedisProcess.stderr);
      }));
      return newRedisProcess;
    }

    setUpAll(() async {
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
        await redisCache.set('expiringkey', 'expiringValue', expiration: Duration(milliseconds: 1));
        await Future.delayed(Duration(milliseconds: 100));
        await expectLater(await redisCache.get('expiringkey'), isNull);
        expect(logMessages, isEmpty);
      });
    });

    test('Verify two caches with different versions give different results for keys', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await redisCache.set('differentVersionKey', 'value1');
        await redisCacheAlt.set('differentVersionKey', 'value2');
        await expectLater(await redisCache.get('differentVersionKey'), 'value1');
        await expectLater(await redisCacheAlt.get('differentVersionKey'), 'value2');
        expect(logMessages, isEmpty);
      });
    });

    test('Verify disconnected cache logs errors and returns nulls', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        RedisCache redisCacheBroken = RedisCache('redis://localhost:9502', 'cversion');
        try {
          await redisCacheBroken.set('aKey', 'value');
          await expectLater(await redisCacheBroken.get('aKey'), isNull);
          await redisCacheBroken.remove('aKey');
          expect(logMessages.join('\n'), stringContainsInOrder([
            'no cache available when setting key cversion+aKey',
            'no cache available when getting key cversion+aKey',
            'no cache available when removing key cversion+aKey',
          ]));
        } finally {
          await redisCacheBroken.shutdown();
        }
      });
    });

    test('Verify cache that starts out disconnected retries and works (slow)', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        RedisCache redisCacheRepairable = RedisCache('redis://localhost:9503', 'cversion');
        try {
          // Wait for a retry message.
          while(logMessages.length < 2) {
            await(Future.delayed(Duration(milliseconds: 50)));
          }
          expect(logMessages.join('\n'), stringContainsInOrder([
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

    test('Verify that cache that stops responding temporarily times out and can recover', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];
        await redisCache.set('beforeStop', 'truth');
        redisProcess.kill(ProcessSignal.sigstop);
        // Don't fail the test before sending sigcont.
        var beforeStop = await redisCache.get('beforeStop');
        await redisCache.disconnected;
        redisProcess.kill(ProcessSignal.sigcont);
        expect(beforeStop, isNull);
        await redisCache.connected;
        await expectLater(await redisCache.get('beforeStop'), equals('truth'));
        expect(logMessages.join('\n'), stringContainsInOrder([
          'timeout on get operation for key aversion+beforeStop',
          '(aversion): reconnecting',
          '(aversion): Connected to redis server',
        ]));
      });
    }, onPlatform: {'windows': Skip('Windows does not have sigstop/sigcont')});

    test('Verify cache that starts out connected but breaks retries until reconnection (slow)', () async {
      await singleTestOnly.synchronized(() async {
        logMessages = [];

        redisAltProcess = await startRedisProcessAndDrainIO(9504);
        RedisCache redisCacheHealing = RedisCache('redis://localhost:9504', 'cversion');
        try {
          await redisCacheHealing.connected;
          await redisCacheHealing.set('missingKey', 'value');
          // Kill process out from under the cache.
          redisAltProcess.kill();
          await redisAltProcess.exitCode;
          redisAltProcess = null;

          // Try to talk to the cache and get an error.  Wait for the disconnect
          // to be recognized.
          await expectLater(await redisCacheHealing.get('missingKey'), isNull);
          await redisCacheHealing.disconnected;

          // Start the server and verify we connect appropriately.
          redisAltProcess = await startRedisProcessAndDrainIO(9504);
          await redisCacheHealing.connected;
          expect(logMessages.join('\n'), stringContainsInOrder([
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

      server = CommonServer(sdkPath, container, cache);
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

    tearDownAll(() async {
      await server.shutdown();
    });

    setUp(() {
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
    });

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
