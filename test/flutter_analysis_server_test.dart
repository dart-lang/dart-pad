// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.flutter_analyzer_server_test;

import 'dart:io';

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/analysis_servers.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/protos/dart_services.pbserver.dart';
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:test/test.dart';

final channel = Platform.environment['FLUTTER_CHANNEL'] ?? stableChannel;
void main() => defineTests();

void defineTests() {
  group('Flutter SDK analysis_server', () {
    late AnalysisServerWrapper analysisServer;

    setUp(() async {
      final sdk = Sdk.create(channel);
      analysisServer =
          FlutterAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
      await analysisServer.init();
    });

    tearDown(() async {
      await analysisServer.shutdown();
    });

    test('analyze counter app', () async {
      final results = await analysisServer.analyze(sampleCodeFlutterCounter);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results =
          await analysisServer.analyze(sampleCodeFlutterDraggableCard);
      expect(results.issues, isEmpty);
    });
  });

  group(
      'Flutter SDK analysis_server with analysis '
      'servers', () {
    late AnalysisServersWrapper analysisServersWrapper;
    late Sdk sdk;
    setUp(() async {
      sdk = Sdk.create(channel);
      analysisServersWrapper = AnalysisServersWrapper(sdk.dartSdkPath);
      await analysisServersWrapper.warmup();
    });

    tearDown(() async {
      await analysisServersWrapper.shutdown();
    });

    test('reports errors with Flutter code', () async {
      late AnalysisResults results;
      results = await analysisServersWrapper.analyze('''
import 'package:flutter/material.dart';

String x = 7;

void main() async {
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
''', devMode: false);
      expect(results.issues, hasLength(1));
      final issue = results.issues[0];
      expect(issue.line, 3);
      expect(issue.kind, 'error');
      expect(
          issue.message,
          "A value of type 'int' can't be assigned to a variable of type "
          "'String'.");
    });

    // https://github.com/dart-lang/dart-pad/issues/2005
    test('reports lint with Flutter code', () async {
      late AnalysisResults results;
      results = await analysisServersWrapper.analyze('''
import 'package:flutter/material.dart';

void main() async {
  var unknown;
  print(unknown);

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
''', devMode: false);
      expect(results.issues, hasLength(1));
      final issue = results.issues[0];
      expect(issue.line, 4);
      expect(issue.kind, 'info');
      if (sdk.channel == 'master') {
        expect(issue.message,
            'An uninitialized variable should have an explicit type annotation.');
      } else {
        expect(
            issue.message, 'Prefer typing uninitialized variables and fields.');
      }
    });

    test('analyze counter app', () async {
      final results = await analysisServersWrapper
          .analyze(sampleCodeFlutterCounter, devMode: false);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results = await analysisServersWrapper
          .analyze(sampleCodeFlutterDraggableCard, devMode: false);
      expect(results.issues, isEmpty);
    });

    test('analyze counter app', () async {
      final results = await analysisServersWrapper
          .analyze(sampleCodeFlutterCounter, devMode: false);
      expect(results.issues, isEmpty);
    });

    test('analyze Draggable Physics sample', () async {
      final results = await analysisServersWrapper
          .analyze(sampleCodeFlutterDraggableCard, devMode: false);
      expect(results.issues, isEmpty);
    });
  });

  group('CommonServerImpl flutter analyze', () {
    late CommonServerImpl commonServerImpl;

    _MockContainer container;
    _MockCache cache;

    setUp(() async {
      container = _MockContainer();
      cache = _MockCache();
      final sdk = Sdk.create(channel);
      commonServerImpl = CommonServerImpl(container, cache, sdk);
      await commonServerImpl.init();
    });

    tearDown(() async {
      await commonServerImpl.shutdown();
    });

    test('counter app', () async {
      final results = await commonServerImpl
          .analyze(SourceRequest()..source = sampleCodeFlutterCounter);
      expect(results.issues, isEmpty);
    });

    test('Draggable Physics sample', () async {
      final results = await commonServerImpl
          .analyze(SourceRequest()..source = sampleCodeFlutterDraggableCard);
      expect(results.issues, isEmpty);
    });
  });

  ///----------------------------------------------------------------
  /// Beginning of multi file files={} tests group:
  group('MULTI FILE files={} Tests', () {
    group('Flutter SDK analysis_server files={} variation', () {
      late AnalysisServerWrapper analysisServer;

      setUp(() async {
        final sdk = Sdk.create(channel);
        analysisServer =
            FlutterAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
        await analysisServer.init();
      });

      tearDown(() async {
        await analysisServer.shutdown();
      });

      test('analyzeFiles counter app files={}', () async {
        final results = await analysisServer
            .analyzeFiles({kMainDart: sampleCodeFlutterCounter});
        expect(results.issues, isEmpty);
      });

      test('analyzeFiles Draggable Physics sample files={}', () async {
        final results = await analysisServer
            .analyzeFiles({kMainDart: sampleCodeFlutterDraggableCard});
        expect(results.issues, isEmpty);
      });
    });

    group(
        'Flutter SDK analysis_server with analysis files={}'
        'servers', () {
      late AnalysisServersWrapper analysisServersWrapper;
      late Sdk sdk;
      setUp(() async {
        sdk = Sdk.create(channel);
        analysisServersWrapper = AnalysisServersWrapper(sdk.dartSdkPath);
        await analysisServersWrapper.warmup();
      });

      tearDown(() async {
        await analysisServersWrapper.shutdown();
      });

      test('reports errors with Flutter code files={}', () async {
        late AnalysisResults results;
        results = await analysisServersWrapper.analyzeFiles({
          kMainDart: '''
import 'package:flutter/material.dart';

String x = 7;

void main() async {
  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
'''
        }, kMainDart, devMode: false);
        expect(results.issues, hasLength(1));
        final issue = results.issues[0];
        expect(issue.line, 3);
        expect(issue.kind, 'error');
        expect(
            issue.message,
            "A value of type 'int' can't be assigned to a variable of type "
            "'String'.");
      });

      // https://github.com/dart-lang/dart-pad/issues/2005
      test('reports lint with Flutter code files={}', () async {
        late AnalysisResults results;
        results = await analysisServersWrapper.analyzeFiles({
          kMainDart: '''
import 'package:flutter/material.dart';

void main() async {
  var unknown;
  print(unknown);

  runApp(MaterialApp(
      debugShowCheckedModeBanner: false, home: Scaffold(body: HelloWorld())));
}

class HelloWorld extends StatelessWidget {
  @override
  Widget build(context) => const Center(child: Text('Hello world'));
}
'''
        }, kMainDart, devMode: false);
        expect(results.issues, hasLength(1));
        final issue = results.issues[0];
        expect(issue.line, 4);
        expect(issue.kind, 'info');
        if (sdk.channel == 'master') {
          expect(issue.message,
              'An uninitialized variable should have an explicit type annotation.');
        } else {
          expect(issue.message,
              'Prefer typing uninitialized variables and fields.');
        }
      });

      test('analyzeFiles counter app files={}', () async {
        final results = await analysisServersWrapper.analyzeFiles(
            {kMainDart: sampleCodeFlutterCounter}, kMainDart,
            devMode: false);
        expect(results.issues, isEmpty);
      });

      test('analyzeFiles Draggable Physics sample files={}', () async {
        final results = await analysisServersWrapper.analyzeFiles(
            {kMainDart: sampleCodeFlutterDraggableCard}, kMainDart,
            devMode: false);
        expect(results.issues, isEmpty);
      });

      test('analyzeFiles counter app files={}', () async {
        final results = await analysisServersWrapper.analyzeFiles(
            {kMainDart: sampleCodeFlutterCounter}, kMainDart,
            devMode: false);
        expect(results.issues, isEmpty);
      });

      test('analyzeFiles Draggable Physics sample files={}', () async {
        final results = await analysisServersWrapper.analyzeFiles(
            {kMainDart: sampleCodeFlutterDraggableCard}, kMainDart,
            devMode: false);
        expect(results.issues, isEmpty);
      });
    });

    group('CommonServerImpl flutter analyzeFiles files={}', () {
      late CommonServerImpl commonServerImpl;

      _MockContainer container;
      _MockCache cache;

      setUp(() async {
        container = _MockContainer();
        cache = _MockCache();
        final sdk = Sdk.create(channel);
        commonServerImpl = CommonServerImpl(container, cache, sdk);
        await commonServerImpl.init();
      });

      tearDown(() async {
        await commonServerImpl.shutdown();
      });

      test('counter app files={}', () async {
        final results = await commonServerImpl.analyzeFiles(SourceFilesRequest(
            files: {kMainDart: sampleCodeFlutterCounter},
            activeSourceName: kMainDart,
            offset: 0));
        expect(results.issues, isEmpty);
      });

      test('Draggable Physics sample files={}', () async {
        final results = await commonServerImpl.analyzeFiles(SourceFilesRequest(
            files: {kMainDart: sampleCodeFlutterDraggableCard},
            activeSourceName: kMainDart));
        expect(results.issues, isEmpty);
      });
    });
  });
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
