// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A benchmark library. This library supports running benchmarks which can
 * run asynchronously.
 */
library dartpad_server.bench;

import 'dart:async';

// TODO: add tests

// TODO: refactor into a benchmark model, runner, and reporter

abstract class Benchmark {
  final String name;

  Benchmark(this.name);

  Future perform();

  String toString() => name;
}

class BenchmarkHarness {

  Future benchmark(List<Benchmark> benchmarks) {
    if (isCheckedMode()) {
      print('WARNING: You are running in checked mode. Benchmarks should be run'
          ' in unchecked,\nnon-debug mode. I.e., run this from the command-line,'
          ' not the Editor.');
      print('(see also www.dartlang.org/articles/benchmarking)');
      print('');
    }

    print('Running ${benchmarks.length} benchmarks.');
    print('');

    return Future.forEach(benchmarks, benchmarkSingle);
  }

  Future<BenchMarkResult> benchmarkSingle(Benchmark benchmark) {
    return _warmup(benchmark).then((_) {
      return _measure(benchmark);
    }).then((BenchMarkResult result) {
      print(result);
      return result;
    });
  }

  Future _warmup(Benchmark benchmark) {
    return _time(benchmark, 2, 1000);
  }

  Future<BenchMarkResult> _measure(Benchmark benchmark) {
    return _time(benchmark, 10, 2000);
  }

  Future<BenchMarkResult> _time(Benchmark benchmark,
      int minIterations, int minMillis) {
    BenchMarkResult result = new BenchMarkResult(benchmark);
    Stopwatch timer = new Stopwatch()..start();

    return Future.doWhile(() {
      if (result.iteration >= minIterations && timer.elapsedMilliseconds >= minMillis) {
        return false;
      }

      result.iteration++;
      return benchmark.perform().then((_) => true);
    }).then((_) {
      timer.stop();
      result.microseconds = timer.elapsedMicroseconds;
      return result;
    });
  }
}

class BenchMarkResult {
  final Benchmark benchmark;
  int iteration = 0;
  int microseconds = 0;

  BenchMarkResult(this.benchmark);

  double _averageMilliseconds() => (microseconds / iteration) / 1000.0;

  double _averageMicroseconds() => microseconds / iteration;

  String toString() => '[${benchmark.name.padRight(23)}: '
      '${_averageMilliseconds().toStringAsFixed(3).padLeft(8)}ms]';
}

bool isCheckedMode() {
  try {
    String result;
    result = _intVal;
    return false;
  } catch (e) {
    return true;
  }
}

dynamic get _intVal => 1 + 2;
