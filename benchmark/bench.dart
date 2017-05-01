// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.bench;

import 'dart:async';

import 'package:services/src/analysis_server.dart';
import 'package:services/src/analyzer.dart';
import 'package:services/src/bench.dart';
import 'package:services/src/common.dart';
import 'package:services/src/compiler.dart';

void main(List<String> args) {
  bool json = args.contains('--json');

  BenchmarkHarness harness = new BenchmarkHarness(json: json);

  List<Benchmark> benchmarks = [
    new AnalyzerBenchmark('hello', sampleCode),
    new AnalyzerBenchmark('hellohtml', sampleCodeWeb),
    new AnalyzerBenchmark('sunflower', _sunflower),

    new AnalysisServerBenchmark('hello', sampleCode),
    new AnalysisServerBenchmark('hellohtml', sampleCodeWeb),
    new AnalysisServerBenchmark('sunflower', _sunflower),

    new Dart2jsBenchmark('hello', sampleCode),
    new Dart2jsBenchmark('hellohtml', sampleCodeWeb),
    new Dart2jsBenchmark('sunflower', _sunflower),
  ];

  harness.benchmark(benchmarks);
}

class AnalyzerBenchmark extends Benchmark {
  final String source;
  Analyzer analyzer;

  AnalyzerBenchmark(String name, this.source) : super('analyzer.${name}') {
    analyzer = new Analyzer(getSdkPath());
  }

  Future perform() => analyzer.analyze(source);
}

class Dart2jsBenchmark extends Benchmark {
  final String source;
  Compiler compiler;

  Dart2jsBenchmark(String name, this.source) : super('dart2js.${name}') {
    compiler = new Compiler(getSdkPath());
  }

  Future perform() {
    return compiler.compile(source).then((CompilationResults result) {
      if (!result.success) throw result;
    });
  }
}

class AnalysisServerBenchmark extends Benchmark {
  final String source;
  AnalysisServerWrapper analysisServer;

  AnalysisServerBenchmark(String name, this.source)
      : super('completion.${name}') {
    analysisServer = new AnalysisServerWrapper(getSdkPath());
  }

  Future init() => analysisServer.init();

  Future perform() => analysisServer.complete(source, 30);

  Future tearDown() => analysisServer.shutdown();
}

final String _sunflower = '''
library sunflower;

import 'dart:html';
import 'dart:math' as math;

main() {
  new Sunflower();
}

class Sunflower {
  static const String ORANGE = "orange";
  static const SEED_RADIUS = 2;
  static const SCALE_FACTOR = 4;
  static const TAU = math.PI * 2;
  static const MAX_D = 300;

  CanvasRenderingContext2D ctx;
  num xc, yc;
  num seeds = 0;
  num PHI;

  Sunflower() {
    PHI = (math.sqrt(5) + 1) / 2;

    CanvasElement canvas = querySelector("#canvas");
    xc = yc = MAX_D / 2;
    ctx = canvas.getContext("2d");

    InputElement slider = querySelector("#slider");
    slider.onChange.listen((Event e) {
      seeds = int.parse(slider.value);
      drawFrame();
    });

    seeds = int.parse(slider.value);

    drawFrame();
  }

  // Draw the complete figure for the current number of seeds.
  void drawFrame() {
    ctx.clearRect(0, 0, MAX_D, MAX_D);
    for (var i=0; i<seeds; i++) {
      var theta = i * TAU / PHI;
      var r = math.sqrt(i) * SCALE_FACTOR;
      var x = xc + r * math.cos(theta);
      var y = yc - r * math.sin(theta);
      drawSeed(x,y);
    }
  }

  // Draw a small circle representing a seed centered at (x,y).
  void drawSeed(num x, num y) {
    ctx.beginPath();
    ctx.lineWidth = 2;
    ctx.fillStyle = ORANGE;
    ctx.strokeStyle = ORANGE;
    ctx.arc(x, y, SEED_RADIUS, 0, TAU, false);
    ctx.fill();
    ctx.closePath();
    ctx.stroke();
  }
}
''';
