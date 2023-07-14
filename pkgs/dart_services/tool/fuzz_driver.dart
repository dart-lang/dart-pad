// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// This tool drives the services API with a large number of files and fuzz
/// test variations. This should be run over all of the co19 tests in the SDK
/// prior to each deployment of the server.
library;

import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:dart_services/src/analysis_server.dart' as analysis_server;
import 'package:dart_services/src/common_server_impl.dart';
import 'package:dart_services/src/compiler.dart' as comp;
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;
import 'package:dart_services/src/sdk.dart';
import 'package:dart_services/src/server_cache.dart';

bool serverBasedCall = false;
bool verbose = false;
bool dumpSrc = false;
bool dumpPerf = false;
bool dumpDelta = false;

late CommonServerImpl commonServerImpl;
late MockCache cache;
analysis_server.AnalysisServerWrapper? analysisServer;

late comp.Compiler compiler;

Random random = Random(0);
int maxMutations = 2;
int iterations = 5;
String commandToRun = 'ALL';
bool dumpServerComms = false;

late OperationType lastExecuted;
int? lastOffset;

Future<void> main(List<String> args) async {
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
  final sdk = Sdk.create(stableChannel);
  print(sdk.dartSdkPath);

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
      await testPath(fse.path, analysisServer!, compiler);
    } catch (e) {
      print(e);
      print('FAILED: ${fse.path}');

      // Try and re-cycle the services for the next test after the crash
      await setupTools(sdk);
    }
  }

  print('Shutting down');

  await analysisServer!.shutdown();
  await commonServerImpl.shutdown();
}

/// Init the tools, and warm them up
Future<void> setupTools(Sdk sdk) async {
  print('Executing setupTools');
  await analysisServer?.shutdown();

  print('SdKPath: ${sdk.dartSdkPath}');

  cache = MockCache();
  commonServerImpl = CommonServerImpl(cache, sdk);
  await commonServerImpl.init();

  analysisServer =
      analysis_server.DartAnalysisServerWrapper(dartSdkPath: sdk.dartSdkPath);
  await analysisServer!.init();

  print('Warming up compiler');
  compiler = comp.Compiler(sdk);
  await compiler.warmup();
  print('SetupTools done');
}

Future<void> testPath(
    String path,
    analysis_server.AnalysisServerWrapper wrapper,
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
    if (dumpSrc) print(src);

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
          throw StateError('Unknown command: $commandToRun');
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
  lastExecuted = OperationType.analysis;
  final sw = Stopwatch()..start();

  lastOffset = null;
  if (serverBasedCall) {
    final request = proto.SourceRequest();
    request.source = src;
    await withTimeOut(commonServerImpl.analyze(request));
    await withTimeOut(commonServerImpl.analyze(request));
  } else {
    await withTimeOut(analysisServer.analyze(src));
    await withTimeOut(analysisServer.analyze(src));
  }

  if (dumpPerf) print('PERF: ANALYSIS: ${sw.elapsedMilliseconds}');
  return sw.elapsedMilliseconds / 2.0;
}

Future<num> testCompilation(String src, comp.Compiler compiler) async {
  lastExecuted = OperationType.compilation;
  final sw = Stopwatch()..start();

  lastOffset = null;
  if (serverBasedCall) {
    final request = proto.CompileRequest();
    request.source = src;
    await withTimeOut(commonServerImpl.compile(request));
  } else {
    await withTimeOut(compiler.compile(src));
  }

  if (dumpPerf) print('PERF: COMPILATION: ${sw.elapsedMilliseconds}');
  return sw.elapsedMilliseconds;
}

Future<num> testDocument(
    String src, analysis_server.AnalysisServerWrapper analysisServer) async {
  lastExecuted = OperationType.document;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i docs completed');
    lastOffset = i;
    if (serverBasedCall) {
      final request = proto.SourceRequest();
      request.source = src;
      request.offset = i;
      log(await withTimeOut(commonServerImpl.document(request)));
    } else {
      log(await withTimeOut(analysisServer.dartdoc(src, i)));
    }
    if (dumpPerf) print('PERF: DOCUMENT: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testCompletions(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.completion;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i completes');
    lastOffset = i;
    if (serverBasedCall) {
      final request = proto.SourceRequest()
        ..source = src
        ..offset = i;
      await withTimeOut(commonServerImpl.complete(request));
    } else {
      await withTimeOut(wrapper.complete(src, i));
    }
    if (dumpPerf) print('PERF: COMPLETIONS: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFixes(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.fixes;
  final sw = Stopwatch()..start();
  for (var i = 0; i < src.length; i++) {
    final sw2 = Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print('INC: $i fixes');
    lastOffset = i;
    if (serverBasedCall) {
      final request = proto.SourceRequest();
      request.source = src;
      request.offset = i;
      await withTimeOut(commonServerImpl.fixes(request));
    } else {
      await withTimeOut(wrapper.getFixes(src, i));
    }
    if (dumpPerf) print('PERF: FIXES: ${sw2.elapsedMilliseconds}');
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFormat(String src) async {
  lastExecuted = OperationType.format;
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

  if (dumpDelta) {
    log('Delta: $s');
  }
  final newStr = src.substring(0, i - 1) + s + src.substring(i);
  return newStr;
}

class MockCache implements ServerCache {
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

enum OperationType {
  compilation,
  analysis,
  completion,
  document,
  fixes,
  format
}

void log(dynamic obj) {
  if (verbose) {
    print('${DateTime.now()} $obj');
  }
}
