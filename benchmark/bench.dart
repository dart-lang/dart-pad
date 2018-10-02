// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.bench;

import 'dart:async';

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/bench.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';

void main(List<String> args) {
  bool json = args.contains('--json');

  BenchmarkHarness harness = BenchmarkHarness(asJson: json);

  List<Benchmark> benchmarks = [
    AnalyzerBenchmark('hello', sampleCode),
    AnalyzerBenchmark('hellohtml', sampleCodeWeb),
    AnalyzerBenchmark('sunflower', _sunflower),
    AnalysisServerBenchmark('hello', sampleCode),
    AnalysisServerBenchmark('hellohtml', sampleCodeWeb),
    AnalysisServerBenchmark('sunflower', _sunflower),
    Dart2jsBenchmark('hello', sampleCode),
    Dart2jsBenchmark('hellohtml', sampleCodeWeb),
    Dart2jsBenchmark('sunflower', _sunflower),
  ];

  harness.benchmark(benchmarks);
}

class AnalyzerBenchmark extends Benchmark {
  final String source;
  AnalysisServerWrapper analysisServer;

  AnalyzerBenchmark(String name, this.source) : super('analyzer.${name}') {
    analysisServer = AnalysisServerWrapper(sdkPath);
  }

  Future init() => analysisServer.init();

  Future perform() => analysisServer.analyze(source);

  Future tearDown() => analysisServer.shutdown();
}

class Dart2jsBenchmark extends Benchmark {
  final String source;
  final Compiler compiler;

  Dart2jsBenchmark(String name, this.source)
      : compiler = Compiler(sdkPath),
        super('dart2js.${name}');

  Future perform() {
    return compiler.compile(source).then((CompilationResults result) {
      if (!result.success) throw result;
    });
  }
}

class AnalysisServerBenchmark extends Benchmark {
  final String source;
  final AnalysisServerWrapper analysisServer;

  AnalysisServerBenchmark(String name, this.source)
      : analysisServer = AnalysisServerWrapper(sdkPath),
        super('completion.${name}');

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
