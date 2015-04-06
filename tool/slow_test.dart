// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io' as io;

import 'package:cli_util/cli_util.dart' as cli_util;
import 'package:services/src/analysis_server.dart' as analysis_server;
import 'package:services/src/analyzer.dart' as ana;
import 'package:services/src/compiler.dart' as comp;

main (List<String> args) async {
  if (args.length == 0) {
    print ("Usage: slow_test path_to_test_collection");
    io.exit(1);
  }

  String testCollectionRoot = args[0];

  io.Directory sdkDir = cli_util.getSdkDir([]);
  var analysisServer = new analysis_server.AnalysisServerWrapper(sdkDir.path);
  // TODO(lukechurch): Add a warmup method so it follows the same pattern
  await analysisServer.complete("main() { int b = 2;  b++;   b. }", 10);

  var analyzer = new ana.Analyzer(sdkDir.path);
  await analyzer.warmup();

  var compiler = new comp.Compiler(sdkDir.path);
  await compiler.warmup();

  var fses = [];

  if (io.FileSystemEntity.isDirectorySync(testCollectionRoot)) {
    io.Directory dir = new io.Directory(testCollectionRoot);
    fses = dir.listSync(recursive: true);
  } else {
    fses = [ new io.File(testCollectionRoot) ];
  }

  for (var fse in fses) {
    if (!fse.path.endsWith('.dart')) continue;

    try {
      await testPath(fse.path, analysisServer, analyzer, compiler);
    } catch (e) {
      print (e);
      print ("FAILED: ${fse.path}");

      // Try and re-cycle the services for the next test after the crash
      analysisServer = new analysis_server.AnalysisServerWrapper(sdkDir.path);
      await analysisServer.complete("main() { int b = 2;  b++;   b. }", 10);

      analyzer = new ana.Analyzer(sdkDir.path);
      await analyzer.warmup();

      compiler = new comp.Compiler(sdkDir.path);
      await compiler.warmup();
    }
  }
}

testPath(String path,
             analysis_server.AnalysisServerWrapper wrapper,
             ana.Analyzer analyzer,
             comp.Compiler compiler) async {

  var f = new io.File(path);
  String src = f.readAsStringSync();
  var averageCompletionTime = await testCompletions(src, wrapper);
  var averageAnalysisTime = await testAnalysis(src, analyzer);
  var averageDocumentTime = await testDocument(src, analyzer);
  var averageCompilationTime = await testCompilation(src, compiler);
  var averageFixesTime = await testFixes(src, wrapper);

  print (
      "$path, "
      "${averageCompilationTime.toStringAsFixed(2)}ms, "
      "${averageAnalysisTime.toStringAsFixed(2)}ms, "
      "${averageCompletionTime.toStringAsFixed(2)}ms, "
      "${averageDocumentTime.toStringAsFixed(2)}ms, "
      "${averageFixesTime.toStringAsFixed(2)}ms"
      );
}

testAnalysis(String src, ana.Analyzer analyzer) async {
  Stopwatch sw = new Stopwatch()..start();
  await analyzer.analyze(src);
  return sw.elapsedMilliseconds;
}

testCompilation(String src, comp.Compiler compiler) async {
  Stopwatch sw = new Stopwatch()..start();
  await compiler.compile(src);
  return sw.elapsedMilliseconds;
}

testDocument(String src, ana.Analyzer analyzer) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    await analyzer.dartdoc(src, i);
  }
  return sw.elapsedMilliseconds / src.length;
}

testCompletions(String src, analysis_server.AnalysisServerWrapper wrapper) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    await wrapper.complete(src, i);
  }
  return sw.elapsedMilliseconds / src.length;
}

testFixes(String src, analysis_server.AnalysisServerWrapper wrapper) async {
  Stopwatch sw = new Stopwatch()..start();
  for (int i = 0; i < src.length; i++) {
    await wrapper.getFixes(src, i);
  }
  return sw.elapsedMilliseconds / src.length;
}
