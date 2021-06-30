// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.flutter_analyzer_server_test;

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/analysis_servers.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/protos/dart_services.pbserver.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  for (final nullSafety in [false, true]) {
    group('Null ${nullSafety ? 'Safe' : 'Unsafe'} Flutter SDK analysis_server',
        () {
      late AnalysisServerWrapper analysisServer;

      setUp(() async {
        analysisServer = FlutterAnalysisServerWrapper(nullSafety);
        await analysisServer.init();
        await analysisServer.warmup();
      });

      tearDown(() async {
        await analysisServer.shutdown();
      });

      test('analyze counter app', () async {
        final results = await analysisServer.analyze(nullSafety
            ? sampleCodeFlutterCounterNullSafe
            : sampleCodeFlutterCounter);
        expect(results.issues, isEmpty);
      });

      test('analyze Draggable Physics sample', () async {
        final results = await analysisServer.analyze(nullSafety
            ? sampleCodeFlutterDraggableCardNullSafe
            : sampleCodeFlutterDraggableCard);
        expect(results.issues, isEmpty);
      });
    });

    group(
        'Null ${nullSafety ? 'Safe' : 'Unsafe'} Flutter SDK analysis_server with analysis servers',
        () {
      late AnalysisServersWrapper analysisServersWrapper;

      setUp(() async {
        analysisServersWrapper = AnalysisServersWrapper(nullSafety);
        await analysisServersWrapper.warmup();
      });

      tearDown(() async {
        await analysisServersWrapper.shutdown();
      });

      test('analyze counter app', () async {
        final results = await analysisServersWrapper.analyze(nullSafety
            ? sampleCodeFlutterCounterNullSafe
            : sampleCodeFlutterCounter);
        expect(results.issues, isEmpty);
      });

      test('analyze Draggable Physics sample', () async {
        final results = await analysisServersWrapper.analyze(nullSafety
            ? sampleCodeFlutterDraggableCardNullSafe
            : sampleCodeFlutterDraggableCard);
        expect(results.issues, isEmpty);
      });
    });

    group(
        'Null ${nullSafety ? 'Safe' : 'Unsafe'} CommonServerImpl flutter analyze',
        () {
      late CommonServerImpl commonServerImpl;

      _MockContainer container;
      _MockCache cache;

      setUp(() async {
        container = _MockContainer();
        cache = _MockCache();
        commonServerImpl = CommonServerImpl(container, cache, nullSafety);
        await commonServerImpl.init();
      });

      tearDown(() async {
        await commonServerImpl.shutdown();
      });

      test('counter app', () async {
        final results = await commonServerImpl.analyze(SourceRequest()
          ..source = nullSafety
              ? sampleCodeFlutterCounterNullSafe
              : sampleCodeFlutterCounter);
        expect(results.issues, isEmpty);
      });

      test('Draggable Physics sample', () async {
        final results = await commonServerImpl.analyze(SourceRequest()
          ..source = nullSafety
              ? sampleCodeFlutterDraggableCardNullSafe
              : sampleCodeFlutterDraggableCard);
        expect(results.issues, isEmpty);
      });
    });
  }
}

class _MockContainer implements ServerContainer {
  @override
  String get version => vmVersion;
}

class _MockCache implements ServerCache {
  @override
  Future<String?> get(String key) => Future<String?>.value(null);

  @override
  Future<void> set(String key, String value, {Duration? expiration}) =>
      Future.value();

  @override
  Future<void> remove(String key) => Future.value();

  @override
  Future<void> shutdown() => Future.value();
}
