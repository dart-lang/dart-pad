// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.redis_cache_test;

import 'dart:async';
import 'dart:io';

import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:logging/logging.dart';
import 'package:pedantic/pedantic.dart';
import 'package:synchronized/synchronized.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
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
}
