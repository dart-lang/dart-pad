// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: only_throw_errors

import 'dart:async';

import 'package:dart_services/src/analysis_server.dart';
import 'package:dart_services/src/common.dart';
import 'package:dart_services/src/compiler.dart';
import 'package:dart_services/src/logging.dart';
import 'package:dart_services/src/protos/dart_services.pb.dart' as proto;
import 'package:dart_services/src/sdk.dart';
import 'package:logging/logging.dart';

import 'bench_impl.dart';

void main(List<String> args) async {
  final json = args.contains('--json');
  final harness = BenchmarkHarness(asJson: json);
  final compiler = Compiler(Sdk.create(stableChannel));

  Logger.root.level = Level.INFO;
  emitLogsToStdout();

  final benchmarks = <Benchmark>[
    AnalyzerBenchmark('hello', sampleCode),
    AnalyzerBenchmark('hellohtml', sampleCodeWeb),
    AnalyzerBenchmark('sunflower', _sunflower),
    AnalyzerBenchmark('spinning_square', _spinningSquare),
    AnalysisServerBenchmark('hello', sampleCode),
    AnalysisServerBenchmark('hellohtml', sampleCodeWeb),
    AnalysisServerBenchmark('sunflower', _sunflower),
    AnalysisServerBenchmark('spinning_square', _spinningSquare),
    Dart2jsBenchmark('hello', sampleCode, compiler),
    Dart2jsBenchmark('hellohtml', sampleCodeWeb, compiler),
    Dart2jsBenchmark('sunflower', _sunflower, compiler),
    // TODO: dart-services dart2js compile path doesn't currently support
    // compiling Flutter apps.
    // Dart2jsBenchmark('spinning_square', _spinningSquare, compiler),
    DevCompilerBenchmark('hello', sampleCode, compiler),
    DevCompilerBenchmark('hellohtml', sampleCodeWeb, compiler),
    DevCompilerBenchmark('sunflower', _sunflower, compiler),
    DevCompilerBenchmark('spinning_square', _spinningSquare, compiler),
  ];

  await harness.benchmark(benchmarks);
  await compiler.dispose();
}

class AnalyzerBenchmark extends Benchmark {
  final String source;
  final AnalysisServerWrapper analysisServer;

  AnalyzerBenchmark(
    String name,
    this.source,
  )   : analysisServer = DartAnalysisServerWrapper(
            dartSdkPath: Sdk.create(stableChannel).dartSdkPath),
        super('analyzer.$name');

  @override
  Future<void> init() => analysisServer.init();

  @override
  Future<proto.AnalysisResults> perform() => analysisServer.analyze(source);

  @override
  Future<dynamic> tearDown() => analysisServer.shutdown();
}

class Dart2jsBenchmark extends Benchmark {
  final String source;
  final Compiler compiler;

  Dart2jsBenchmark(String name, this.source, this.compiler)
      : super('dart2js.$name');

  @override
  Future<void> perform() {
    return compiler.compile(source).then((CompilationResults result) {
      if (!result.success) throw result;
    });
  }
}

class DevCompilerBenchmark extends Benchmark {
  final String source;
  final Compiler compiler;

  DevCompilerBenchmark(String name, this.source, this.compiler)
      : super('dartdevc.$name');

  @override
  Future<void> perform() {
    return compiler.compileDDC(source).then((DDCCompilationResults result) {
      if (!result.success) throw result;
    });
  }
}

class AnalysisServerBenchmark extends Benchmark {
  final String source;
  final AnalysisServerWrapper analysisServer;

  AnalysisServerBenchmark(String name, this.source)
      : analysisServer = DartAnalysisServerWrapper(
            dartSdkPath: Sdk.create(stableChannel).dartSdkPath),
        super('completion.$name');

  @override
  Future<void> init() => analysisServer.init();

  @override
  Future<proto.CompleteResponse> perform() =>
      analysisServer.complete(source, 30);

  @override
  Future<dynamic> tearDown() => analysisServer.shutdown();
}

final String _sunflower = '''
library sunflower;

import 'dart:html';
import 'dart:math' as math;

main() {
  Sunflower();
}

class Sunflower {
  static const String orange = "orange";
  static const seedRadius = 2;
  static const scaleFactor = 4;
  static const tau = math.pi * 2;
  static const maxD = 300;

  late CanvasRenderingContext2D ctx;
  late num xc, yc;
  num seeds = 0;
  late num phi;

  Sunflower() {
    phi = (math.sqrt(5) + 1) / 2;

    CanvasElement canvas = querySelector("#canvas") as CanvasElement;
    xc = yc = maxD / 2;
    ctx = canvas.getContext("2d") as CanvasRenderingContext2D;

    var slider = querySelector("#slider") as InputElement;
    slider.onChange.listen((Event e) {
      seeds = int.parse(slider.value!);
      drawFrame();
    });

    seeds = int.parse(slider.value!);

    drawFrame();
  }

  // Draw the complete figure for the current number of seeds.
  void drawFrame() {
    ctx.clearRect(0, 0, maxD, maxD);
    for (var i = 0; i < seeds; i++) {
      var theta = i * tau / phi;
      var r = math.sqrt(i) * scaleFactor;
      var x = xc + r * math.cos(theta);
      var y = yc - r * math.sin(theta);
      drawSeed(x, y);
    }
  }

  // Draw a small circle representing a seed centered at (x,y).
  void drawSeed(num x, num y) {
    ctx.beginPath();
    ctx.lineWidth = 2;
    ctx.fillStyle = orange;
    ctx.strokeStyle = orange;
    ctx.arc(x, y, seedRadius, 0, tau, false);
    ctx.fill();
    ctx.closePath();
    ctx.stroke();
  }
}
''';

final _spinningSquare = '''
import 'package:flutter/material.dart';

class SpinningSquare extends StatefulWidget {
  @override
  SpinningSquareState createState() => SpinningSquareState();
}

class SpinningSquareState extends State<SpinningSquare>
    with SingleTickerProviderStateMixin {
  late AnimationController _animation;

  @override
  void initState() {
    super.initState();
    // We use 3600 milliseconds instead of 1800 milliseconds because 0.0 -> 1.0
    // represents an entire turn of the square whereas in the other examples
    // we used 0.0 -> math.pi, which is only half a turn.
    _animation = AnimationController(
      duration: const Duration(milliseconds: 3600),
      vsync: this,
    )..repeat();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _animation,
      child: Container(
        width: 200.0,
        height: 200.0,
        color: const Color(0xFF00FF00),
      ),
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }
}

main() async {
  runApp(Center(child: SpinningSquare()));
}
''';
