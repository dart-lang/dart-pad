// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * This tool drives the services API with a large number of files and fuzz
 * test variations. This should be run over all of the co19 tests in the SDK
 * prior to each deployment of the server.
 */
library services.fuzz_driver;

import 'dart:io' as io;
import 'dart:math';
import 'dart:async';

import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:services/src/analysis_server.dart' as analysis_server;
import 'package:services/src/analyzer.dart' as ana;
import 'package:services/src/compiler.dart' as comp;

import 'package:services/src/common_server.dart';
import 'package:rpc/rpc.dart';

bool _PERF_DUMP = false;
bool _SERVER_BASED_CALL = false;

CommonServer server;
ApiServer apiServer;
MockCache cache;
MockRequestRecorder recorder;
MockCounter counter;
analysis_server.AnalysisServerWrapper analysisServer;
ana.Analyzer analyzer;
comp.Compiler compiler;

var random = new Random(0);
var maxMutations = 2;
var iterations = 5;
String commandToRun = "ALL";

main (List<String> args) async {
  if (args.length == 0) {
    print ('''
Usage: slow_test path_to_test_collection
    [seed = 0]
    [mutations per iteration = 2]
    [iterations = 5]
    [name of command to test = ALL]''');

    io.exit(1);
  }

  // TODO: Replace this with args package.
  int seed = 0;
  String testCollectionRoot = args[0];
  if (args.length >= 2) seed = int.parse(args[1]);
  if (args.length >= 3) maxMutations = int.parse(args[2]);
  if (args.length >= 4) iterations = int.parse(args[3]);
  if (args.length >= 5) commandToRun = args[4];
  io.Directory sdkDir = cli_util.getSdkDir([]);

  // Load the list of files.
  var fileEntities = [];
  if (io.FileSystemEntity.isDirectorySync(testCollectionRoot)) {
    io.Directory dir = new io.Directory(testCollectionRoot);
    fileEntities = dir.listSync(recursive: true);
  } else {
    fileEntities = [ new io.File(testCollectionRoot) ];
  }

  analysis_server.dumpServerMessages = false;

  // Warm up the services.
  await setupTools(sdkDir.path);

  // Main testing loop.
  for (var fse in fileEntities) {
    if (!fse.path.endsWith('.dart')) continue;

    try {
      print ("Seed: $seed");
      random = new Random(seed);
      seed++;
      await testPath(fse.path, analysisServer, analyzer, compiler);

    } catch (e) {
      print (e);
      print ("FAILED: ${fse.path}");

      // Try and re-cycle the services for the next test after the crash
      await setupTools(sdkDir.path);
    }
  }
}

/**
 * Init the tools, and warm them up
 */
setupTools(String sdkPath) async {
  cache = new MockCache();
  recorder = new MockRequestRecorder();
  counter = new MockCounter();
  server = new CommonServer(sdkPath, cache, recorder, counter);
  apiServer = new ApiServer('/api', prettyPrint: true)..addApi(server);

  analysisServer = new analysis_server.AnalysisServerWrapper(sdkPath);
  await analysisServer.warmup();

  analyzer = new ana.Analyzer(sdkPath);
  await analyzer.warmup();

  compiler = new comp.Compiler(sdkPath);
  await compiler.warmup();
}

testPath(String path,
         analysis_server.AnalysisServerWrapper wrapper,
         ana.Analyzer analyzer,
         comp.Compiler compiler) async {
  var f = new io.File(path);
  String src = f.readAsStringSync();

  print (
    'Path, Compilation/ms, Analysis/ms, '
    'Completion/ms, Document/ms, Fixes/ms, Format/ms');

  for (int i = 0; i < iterations; i++) {
    // Run once for each file without mutation.
    var averageCompilationTime = 0;
    var averageAnalysisTime = 0;
    var averageCompletionTime = 0;
    var averageDocumentTime = 0;
    var averageFixesTime = 0;
    var averageFormatTime = 0;

    switch (commandToRun.toLowerCase()) {
      case "all":
        averageCompilationTime = await testCompilation(src, compiler);
        averageCompletionTime = await testCompletions(src, wrapper);
        averageAnalysisTime = await testAnalysis(src, analyzer);
        averageDocumentTime = await testDocument(src, analyzer);
        averageFixesTime = await testFixes(src, wrapper);
        averageFormatTime = await testFormat(src);
        break;

      case "complete":
        averageCompletionTime = await testCompletions(src, wrapper);
        break;
      case "analyze":
        averageAnalysisTime = await testAnalysis(src, analyzer);
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

    print (
        "$path-$i, "
        "${averageCompilationTime.toStringAsFixed(2)}, "
        "${averageAnalysisTime.toStringAsFixed(2)}, "
        "${averageCompletionTime.toStringAsFixed(2)}, "
        "${averageDocumentTime.toStringAsFixed(2)}, "
        "${averageFixesTime.toStringAsFixed(2)}, "
        "${averageFormatTime.toStringAsFixed(2)}"
    );

    if (maxMutations == 0) break;

    // And then for the remainder with an increasing mutated file.
    int noChanges = random.nextInt(maxMutations);

    for (int j = 0; j < noChanges; j++) {
      src = mutate(src);
    }
  }
}

Future<num> testAnalysis(String src, ana.Analyzer analyzer) async {
  Stopwatch sw = new Stopwatch()..start();

  if (_SERVER_BASED_CALL) await server.analyzeGet(source: src);
  else await analyzer.analyze(src);

  if (_PERF_DUMP) print ("PERF: ANALYSIS: ${sw.elapsedMilliseconds}");
  return sw.elapsedMilliseconds;
}

Future<num> testCompilation(String src, comp.Compiler compiler) async {
  Stopwatch sw = new Stopwatch()..start();

  if (_SERVER_BASED_CALL) await server.compileGet(source: src);
  else await compiler.compile(src);

  if (_PERF_DUMP) print ("PERF: COMPILATION: ${sw.elapsedMilliseconds}");
  return sw.elapsedMilliseconds;
}

Future<num> testDocument(String src, ana.Analyzer analyzer) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i docs completed");
    if (_SERVER_BASED_CALL) await server.documentGet(source: src, offset: i);
    else await analyzer.dartdoc(src, i);

    if (_PERF_DUMP) print ("PERF: DOCUMENT: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testCompletions(String src, analysis_server.AnalysisServerWrapper wrapper) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i completes");
    if (_SERVER_BASED_CALL) await server.completeGet(source: src, offset: i);
    else await wrapper.complete(src, i);
    if (_PERF_DUMP) print ("PERF: COMPLETIONS: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFixes(String src, analysis_server.AnalysisServerWrapper wrapper) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    Stopwatch sw2 = new Stopwatch()..start();

    if (i % 1000 == 0 && i > 0) print("INC: $i fixes");
    if (_SERVER_BASED_CALL) await server.fixesGet(source: src, offset: i);
    else await wrapper.getFixes(src, i);

    if (_PERF_DUMP) print ("PERF: FIXES: ${sw2.elapsedMilliseconds}");
  }
  return sw.elapsedMilliseconds / src.length;
}

Future<num> testFormat(String src) async {
  Stopwatch sw = new Stopwatch()..start();
  await server.formatGet(source: src, offset: 0);
  return sw.elapsedMilliseconds;
}

String mutate(String src) {
  var chars = ["{", "}", "[", "]", "'", ",", "!", "@", "#", "\$", "%",
  "^", "&", " ", "(", ")", "null ", "class ", "for ", "void ", "var ",
  "dynamic ", ";", "as ", "is ", ".", "import "];
  String s = chars[random.nextInt(chars.length)];
  int i = random.nextInt(src.length);
  if (i == 0) i = 1;
  String newStr = src.substring(0, i - 1) + s + src.substring(i);
  return newStr;
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
  Future increment(String name, {int increment : 1}) {
    counter.putIfAbsent(name, () => 0);
    return new Future.value(counter[name]++);
  }
}
