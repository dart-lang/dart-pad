// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This tool drives the services API with a large number of files and fuzz
 * test variations. This should be run over all of the co19 tests in the SDK
 * prior to each deployment of the server.
 */
library services.fuzz_driver;

import 'dart:async';
import 'dart:io' as io;
import 'dart:math';

import 'package:rpc/rpc.dart';
import 'package:services/src/analysis_server.dart' as analysis_server;
import 'package:services/src/analyzer.dart' as ana;
import 'package:services/src/common.dart';
import 'package:services/src/common_server.dart';
import 'package:services/src/compiler.dart' as comp;

bool _SERVER_BASED_CALL = false;
bool _VERBOSE = true;
bool _DUMP_SRC = false;
bool _DUMP_PERF = false;
bool _DUMP_DELTA = false;

CommonServer server;
ApiServer apiServer;
MockContainer container;
MockCache cache;
MockRequestRecorder recorder;
MockCounter counter;
analysis_server.AnalysisServerWrapper analysisServer;
ana.Analyzer analyzer;
ana.Analyzer strongAnalyzer;

comp.Compiler compiler;

var random = new Random(0);
var maxMutations = 2;
var iterations = 5;
String commandToRun = "ALL";
bool dumpServerComms = false;

OperationType lastExecuted;
int lastOffset;

main(List<String> args) async {
  if (args.length == 0) {
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
  int seed = 0;
  String testCollectionRoot = args[0];
  if (args.length >= 2) seed = int.parse(args[1]);
  if (args.length >= 3) maxMutations = int.parse(args[2]);
  if (args.length >= 4) iterations = int.parse(args[3]);
  if (args.length >= 5) commandToRun = args[4];
  if (args.length >= 6) dumpServerComms = args[5].toLowerCase() == "true";
  String sdk = getSdkPath();

  // Load the list of files.
  var fileEntities = [];
  if (io.FileSystemEntity.isDirectorySync(testCollectionRoot)) {
    io.Directory dir = new io.Directory(testCollectionRoot);
    fileEntities = dir.listSync(recursive: true);
  } else {
    fileEntities = [new io.File(testCollectionRoot)];
  }

  analysis_server.dumpServerMessages = false;

  int counter = 0;
  Stopwatch sw = new Stopwatch()..start();

  print("About to setuptools");
  print(sdk);

  // Warm up the services.
  await setupTools(sdk);

  print("Setup tools done");

  // Main testing loop.
  for (var fse in fileEntities) {
    counter++;
    if (!fse.path.endsWith('.dart')) continue;

    try {
      print("Seed: $seed, "
          "${((counter/fileEntities.length)*100).toStringAsFixed(2)}%, "
          "Elapsed: ${sw.elapsed}");

      random = new Random(seed);
      seed++;
      await testPath(
          fse.path, analysisServer, analyzer, strongAnalyzer, compiler);
    } catch (e) {
      print(e);
      print("FAILED: ${fse.path}");

      // Try and re-cycle the services for the next test after the crash
      await setupTools(sdk);
    }
  }
}

/**
 * Init the tools, and warm them up
 */
setupTools(String sdkPath) async {
  print("Executing setupTools");
  if (analysisServer != null) await analysisServer.shutdown();

  print("SdKPath: $sdkPath");

  container = new MockContainer();
  cache = new MockCache();
  recorder = new MockRequestRecorder();
  counter = new MockCounter();
  server = new CommonServer(sdkPath, container, cache, recorder, counter);
  await server.init();

  apiServer = new ApiServer(apiPrefix: '/api', prettyPrint: true)
    ..addApi(server);

  analysisServer = new analysis_server.AnalysisServerWrapper(sdkPath);
  await analysisServer.init();

  print("Warming up analysis server");
  await analysisServer.warmup();

  print("Warming up analyzer");
  analyzer = new ana.Analyzer(sdkPath);
  await analyzer.warmup();

  print("Warming up strong analyzer");
  strongAnalyzer = new ana.Analyzer(sdkPath, strongMode: true);
  await strongAnalyzer.warmup();

  print("Warming up compiler");
  compiler = new comp.Compiler(sdkPath);
  await compiler.warmup();
  print("SetupTools done");
}

testPath(
    String path,
    analysis_server.AnalysisServerWrapper wrapper,
    ana.Analyzer analyzer,
    ana.Analyzer strongAnalyzer,
    comp.Compiler compiler) async {
  var f = new io.File(path);
  String src = f.readAsStringSync();

  print('Path, Compilation/ms, Analysis/ms, '
      'Completion/ms, Document/ms, Fixes/ms, Format/ms');

  for (int i = 0; i < iterations; i++) {
    // Run once for each file without mutation.
    var averageCompilationTime = 0;
    var averageAnalysisTime = 0;
    var averageCompletionTime = 0;
    var averageDocumentTime = 0;
    var averageFixesTime = 0;
    var averageFormatTime = 0;
    if (_DUMP_SRC) print(src);

    try {
      switch (commandToRun.toLowerCase()) {
        case "all":
          averageCompilationTime = await testCompilation(src, compiler);
          averageCompletionTime = await testCompletions(src, wrapper);
          averageAnalysisTime =
              await testAnalysis(src, analyzer, strongAnalyzer);
          averageDocumentTime = await testDocument(src, analyzer);
          averageFixesTime = await testFixes(src, wrapper);
          averageFormatTime = await testFormat(src);
          break;

        case "complete":
          averageCompletionTime = await testCompletions(src, wrapper);
          break;
        case "analyze":
          averageAnalysisTime =
              await testAnalysis(src, analyzer, strongAnalyzer);
          break;

        case "document":
          averageDocumentTime = await testDocument(src, analyzer);
          break;

        case "compile":
          averageCompilationTime = await testCompilation(src, compiler);
          break;

        case "fix":
          averageFixesTime = await testFixes(src, wrapper);
          break;

        case "format":
          averageFormatTime = await testFormat(src);
          break;

        default:
          throw "Unknown command";
      }
    } catch (e, stacktrace) {
      print("===== FAILING OP: $lastExecuted, offset: $lastOffset  =====");
      print(src);
      print("=====                                                 =====");
      print(e);
      print(stacktrace);
      print("===========================================================");

      throw e;
    }

    print("$path-$i, "
        "${averageCompilationTime.toStringAsFixed(2)}, "
        "${averageAnalysisTime.toStringAsFixed(2)}, "
        "${averageCompletionTime.toStringAsFixed(2)}, "
        "${averageDocumentTime.toStringAsFixed(2)}, "
        "${averageFixesTime.toStringAsFixed(2)}, "
        "${averageFormatTime.toStringAsFixed(2)}");

    if (maxMutations == 0) break;

    // And then for the remainder with an increasing mutated file.
    int noChanges = random.nextInt(maxMutations);

    for (int j = 0; j < noChanges; j++) {
      src = mutate(src);
    }
  }
}

Future<num> testAnalysis(
    String src, ana.Analyzer analyzer, ana.Analyzer strongAnalyzer) async {
  lastExecuted = OperationType.Analysis;
  Stopwatch sw = new Stopwatch()..start();

  lastOffset = null;
  if (_SERVER_BASED_CALL)
    await withTimeOut(server.analyzeGet(source: src));
  else
    await withTimeOut(analyzer.analyze(src));

  if (_SERVER_BASED_CALL)
    await withTimeOut(server.analyzeGet(source: src, strongMode: true));
  else
    await withTimeOut(strongAnalyzer.analyze(src));

  if (_DUMP_PERF) print("PERF: ANALYSIS: ${sw.elapsedMilliseconds}");
  return sw.elapsedMilliseconds / 2.0;
}

Future<num> testCompilation(String src, comp.Compiler compiler) async {
  lastExecuted = OperationType.Compilation;
  Stopwatch sw = new Stopwatch()..start();

  lastOffset = null;
  if (_SERVER_BASED_CALL)
    await withTimeOut(server.compileGet(source: src));
  else
    await withTimeOut(compiler.compile(src));

  if (_DUMP_PERF) print("PERF: COMPILATION: ${sw.elapsedMilliseconds}");
  return sw.elapsedMilliseconds;
}

Future<num> testDocument(String src, ana.Analyzer analyzer) async {
  lastExecuted = OperationType.Document;
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i docs completed");
    lastOffset = i;
    if (_SERVER_BASED_CALL) {
      log(await withTimeOut(server.documentGet(source: src, offset: i)));
    } else {
      log(await withTimeOut(analyzer.dartdoc(src, i)));
    }
    if (_DUMP_PERF) print("PERF: DOCUMENT: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testCompletions(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.Completion;
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i completes");
    lastOffset = i;
    if (_SERVER_BASED_CALL)
      await withTimeOut(server.completeGet(source: src, offset: i));
    else
      await withTimeOut(wrapper.complete(src, i));
    if (_DUMP_PERF) print("PERF: COMPLETIONS: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFixes(
    String src, analysis_server.AnalysisServerWrapper wrapper) async {
  lastExecuted = OperationType.Fixes;
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i fixes");
    lastOffset = i;
    if (_SERVER_BASED_CALL) {
      await withTimeOut(server.fixesGet(source: src, offset: i));
    } else {
      await withTimeOut(wrapper.getFixes(src, i));
    }
    if (_DUMP_PERF) print("PERF: FIXES: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFormat(String src) async {
  lastExecuted = OperationType.Format;
  Stopwatch sw = new Stopwatch()..start();
  int i = 0;
  lastOffset = i;
  log(await withTimeOut(server.formatGet(source: src, offset: i)));
  return sw.elapsedMilliseconds;
}

Future withTimeOut(Future f) {
  return f.timeout(new Duration(seconds: 30));
}

String mutate(String src) {
  var chars = [
    "{",
    "}",
    "[",
    "]",
    "'",
    ",",
    "!",
    "@",
    "#",
    "\$",
    "%",
    "^",
    "&",
    " ",
    "(",
    ")",
    "null ",
    "class ",
    "for ",
    "void ",
    "var ",
    "dynamic ",
    ";",
    "as ",
    "is ",
    ".",
    "import "
  ];
  String s = chars[random.nextInt(chars.length)];
  int i = random.nextInt(src.length);
  if (i == 0) i = 1;

  if (_DUMP_DELTA) {
    log("Delta: $s");
  }
  String newStr = src.substring(0, i - 1) + s + src.substring(i);
  return newStr;
}

class MockContainer implements ServerContainer {
  String get version => vmVersion;
}

class MockCache implements ServerCache {
  Future<String> get(String key) => new Future.value(null);
  Future set(String key, String value, {Duration expiration}) =>
      new Future.value();
  Future remove(String key) => new Future.value();
}

class MockRequestRecorder implements SourceRequestRecorder {
  @override
  Future record(String verb, String source, [int offset]) {
    return new Future.value();
  }
}

class MockCounter implements PersistentCounter {
  Map<String, int> counter = {};

  @override
  Future<int> getTotal(String name) {
    counter.putIfAbsent(name, () => 0);
    return new Future.value(counter[name]);
  }

  @override
  Future increment(String name, {int increment: 1}) {
    counter.putIfAbsent(name, () => 0);
    return new Future.value(counter[name]++);
  }
}

enum OperationType {
  Compilation,
  Analysis,
  Completion,
  Document,
  Fixes,
  Format
}

log(dynamic str) {
  if (_VERBOSE) {
    print("${new DateTime.now()} $str");
  }
}
