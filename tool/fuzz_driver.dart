// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This tool drives the services API with a large number of files and fuzz
/// test variations. This should be run over all of the co19 tests in the SDK
/// prior to each deployment of the server.

library services.fuzz_driver;

import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:dart_services/src/analysis_server.dart' as analysis_server;
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/compiler.dart' as comp;
import 'package:dart_services/src/flutter_web.dart';
import 'package:dart_services/src/sdk_manager.dart';
import 'package:dart_services/src/server_cache.dart';
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;

bool _SERVER_BASED_CALL = false;
bool _VERBOSE = false;
bool _DUMP_SRC = false;
bool _DUMP_PERF = false;
bool _DUMP_DELTA = false;

CommonServerImpl commonServerImpl;
MockContainer container;
MockCache cache;
analysis_server.AnalysisServerWrapper analysisServer;

comp.Compiler compiler;

var random = Random(0);
var maxMutations = 2;
var iterations = 5;
String commandToRun = 'ALL';
bool dumpServerComms = false;

OperationType lastExecuted;
int lastOffset;

Future main(List<String> args) async {
  if (args.isEmpty) {
    print('''
Usage: slow_test path_to_test_collection
    [seed = 0]
    [mutations per iteration = 2]
    [iterations = 5]
    [name of command to test = ALL]
    [dump server communications = false]''');

    io.exit(1);
  }

  // TODO: Replace this with args package.
  var seed = 0;
  final testCollectionRoot = args[0];
  if (args.length >= 2) seed = int.parse(args[1]);
  if (args.length >= 3) maxMutations = int.parse(args[2]);
  if (args.length >= 4) iterations = int.parse(args[3]);
  if (args.length >= 5) commandToRun = args[4];
  if (args.length >= 6) dumpServerComms = args[5].toLowerCase() == 'true';
  final sdk = sdkPath;

  // Load the list of files.
  var fileEntities = <io.FileSystemEntity>[];
  if (io.FileSystemEntity.isDirectorySync(testCollectionRoot)) {
    final dir = io.Directory(testCollectionRoot);
    fileEntities = dir.listSync(recursive: true);
  } else {
    fileEntities = [io.File(testCollectionRoot)];
  }

  analysis_server.dumpServerMessages = false;

  var counter = 0;
  final sw = Stopwatch()..start();

  print('About to setuptools');
  print(sdk);

  // Warm up the services.
  await setupTools(sdk);

  print('Setup tools done');

  // Main testing loop.
  for (final fse in fileEntities) {
    counter++;
    if (!fse.path.endsWith('.dart')) continue;

    try {
      print('Seed: $seed, '
          '${((counter / fileEntities.length) * 100).toStringAsFixed(2)}%, '
          'Elapsed: ${sw.elapsed}');

      random = Random(seed);
      seed++;
      await testPath(fse.path, analysisServer, compiler);
    } catch (e) {
      print(e);
      print('FAILED: ${fse.path}');

      // Try and re-cycle the services for the next test after the crash
      await setupTools(sdk);
    }
  }

  print('Shutting down');

  await analysisServer.shutdown();
  await commonServerImpl.shutdown();
}

/// Init the tools, and warm them up
Future setupTools(String sdkPath) async {
  print('Executing setupTools');
  await analysisServer?.shutdown();

  print('SdKPath: $sdkPath');

  final flutterWebManager = FlutterWebManager(SdkManager.flutterSdk);

  container = MockContainer();
  cache = MockCache();
  commonServerImpl =
      CommonServerImpl(sdkPath, flutterWebManager, container, cache);
  await commonServerImpl.init();

  analysisServer =
      analysis_server.AnalysisServerWrapper(sdkPath, flutterWebManager);
  await analysisServer.init();

  print('Warming up analysis server');
  await analysisServer.warmup();

  print('Warming up compiler');
  compiler =
      comp.Compiler(SdkManager.sdk, SdkManager.flutterSdk, flutterWebManager);
  await compiler.warmup();
  print('SetupTools done');
}

Future testPath(String path, analysis_server.AnalysisServerWrapper wrapper,
    comp.Compiler compiler) async {
  final f = io.File(path);
  var src = f.readAsStringSync();

  print('Path, Compilation/ms, Analysis/ms, '
      'Completion/ms, Document/ms, Fixes/ms, Format/ms');

  for (var i = 0; i < iterations; i++) {
    // Run once for each file without mutation.
    num averageCompilationTime = 0;
    num averageAnalysisTime = 0;
    num averageCompletionTime = 0;
    num averageDocumentTime = 0;
    num averageFixesTime = 0;
    num averageFormatTime = 0;
    if (_DUMP_SRC) print(src);

    try {
      switch (commandToRun.toLowerCase()) {
        case 'all':
          averageCompilationTime = await testCompilation(src, compiler);
          averageCompletionTime = await testCompletions(src, wrapper);
          averageAnalysisTime = await testAnalysis(src, wrapper);
          averageDocumentTime = await testDocument(src, wrapper);
          averageFixesTime = await testFixes(src, wrapper);
          averageFormatTime = await testFormat(src);
          break;

        case 'complete':
          averageCompletionTime = await testCompletions(src, wrapper);
          break;
        case 'analyze':
          averageAnalysisTime = await testAnalysis(src, wrapper);
          break;

        case 'document':
          averageDocumentTime = await testDocument(src, wrapper);
          break;

        case 'compile':
          averageCompilationTime = await testCompilation(src, compiler);
          break;

        case 'fix':
          averageFixesTime = await testFixes(src, wrapper);
          break;

        case 'format':
          averageFormatTime = await testFormat(src);
          break;

        default:
          throw 'Unknown command';
      }
    } catch (e, stacktrace) {
      print('===== FAILING OP: $lastExecuted, offset: $lastOffset  =====');
      print(src);
      print('=====                                                 =====');
      print(e);
      print(stacktrace);
      print('===========================================================');

      rethrow;
    }

    print('$path-$i, '
        '${averageCompilationTime.toStringAsFixed(2)}, '
        '${averageAnalysisTime.toStringAsFixed(2)}, '
        '${averageCompletionTime.toStringAsFixed(2)}, '
        '${averageDocumentTime.toStringAsFixed(2)}, '
        '${averageFixesTime.toStringAsFixed(2)}, '
        '${averageFormatTime.toStringAsFixed(2)}');

    if (maxMutations == 0) break;

    // And then for the remainder with an increasing mutated file.
    final noChanges = random.nextInt(maxMutations);

    for (var j = 0; j < noChanges; j++) {
      src = mutate(src);
    }
  }
}

Future<num> testAnalysis(
    String src, analysis_server.AnalysisServerWrapper analysisServer) async {
  lastExecuted = OperationType.Analysis;
  final sw = Stopwatch()..start();

  lastOffset = null;
  if (_SERVER_BASED_CALL) {
    final request = proto.SourceRequest();
    request.source = src;
    await withTimeOut(commonServerImpl.analyze(request));
    await withTimeOut(commonServerImpl.analyze(request));
  } else {
    await withTimeOut(analysisServer.analyze(src));
    await withTimeOut(analysisServer.analyze(src));
  }

  if (_DUMP_PERF) print('PERF: ANALYSIS: ${sw.elapsedMilliseconds}');
  return sw.elapsedMilliseconds / 2.0;
}

Future<num> testCompilation(String src, comp.Compiler compiler) async {
  lastExecuted = OperationType.Compilation;
  final sw = Stopwatch()..start();

  lastOffset = null;
  if (_SERVER_BASED_CALL) {
    final request = proto.CompileRequest();
    request.source = src;
    await withTimeOut(commonServerImpl.compile(request));
  } else {
    await withTimeOut(compiler.compile(src));
  }

  if (_DUMP_PERF) print('PERF: COMPILATION: ${sw.elapsedMilliseconds}');
  return sw.elapsedMilliseconds;
}

Future<num> testDocument(
    String src, analysis_server.AnalysisServerWrapper analysisServer) async {
  lastExecuted = OperationType.Document;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i docs completed');
    lastOffset = i;
    if (_SERVER_BASED_CALL) {
      final request = proto.SourceRequest();
      request.source = src;
      request.offset = i;
      log(await withTimeOut(commonServerImpl.document(request)));
    } else {
      log(await withTimeOut(analysisServer.dartdoc(src, i)));
    }
    if (_DUMP_PERF) print('PERF: DOCUMENT: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testCompletions(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.Completion;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i completes');
    lastOffset = i;
    if (_SERVER_BASED_CALL) {
      final request = proto.SourceRequest()
        ..source = src
        ..offset = i;
      await withTimeOut(commonServerImpl.complete(request));
    } else {
      await withTimeOut(wrapper.complete(src, i));
    }
    if (_DUMP_PERF) print('PERF: COMPLETIONS: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFixes(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.Fixes;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i fixes');
    lastOffset = i;
    if (_SERVER_BASED_CALL) {
      final request = proto.SourceRequest();
      request.source = src;
      request.offset = i;
      await withTimeOut(commonServerImpl.fixes(request));
    } else {
      await withTimeOut(wrapper.getFixes(src, i));
    }
    if (_DUMP_PERF) print('PERF: FIXES: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFormat(String src) async {
  lastExecuted = OperationType.Format;
  final sw = Stopwatch()..start();
  final i = 0;
  lastOffset = i;
  final request = proto.SourceRequest();
  request.source = src;
  request.offset = i;
  log(await withTimeOut(commonServerImpl.format(request)));
  return sw.elapsedMilliseconds;
}

Future<T> withTimeOut<T>(Future<T> f) {
  return f.timeout(Duration(seconds: 30));
}

String mutate(String src) {
  final chars = [
    '{',
    '}',
    '[',
    ']',
    "'",
    ',',
    '!',
    '@',
    '#',
    '\$',
    '%',
    '^',
    '&',
    ' ',
    '(',
    ')',
    'null ',
    'class ',
    'for ',
    'void ',
    'var ',
    'dynamic ',
    ';',
    'as ',
    'is ',
    '.',
    'import '
  ];
  final s = chars[random.nextInt(chars.length)];
  var i = random.nextInt(src.length);
  if (i == 0) i = 1;

  if (_DUMP_DELTA) {
    log('Delta: $s');
  }
  final newStr = src.substring(0, i - 1) + s + src.substring(i);
  return newStr;
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

enum OperationType {
  Compilation,
  Analysis,
  Completion,
  Document,
  Fixes,
  Format
}

final int termWidth = io.stdout.hasTerminal ? io.stdout.terminalColumns : 200;

void log(dynamic obj) {
  if (_VERBOSE) {
    print('${DateTime.now()} $obj');
  }
}
