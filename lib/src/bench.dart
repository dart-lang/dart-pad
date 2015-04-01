// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/**
 * A benchmark library. This library supports running benchmarks which can
 * run asynchronously.
 */
library services.bench;

import 'dart:async';
import 'dart:convert' show JSON;

// TODO: refactor into a benchmark model, runner, and reporter

// TODO: add in mean, % error

abstract class Benchmark {
  final String name;

  Benchmark(this.name);

  Future perform();

  /// Called once when this benchmark will no longer be used.
  Future tearDown() => new Future.value();

  String toString() => name;
}

class BenchmarkHarness {
  final bool json;

  BenchmarkHarness({this.json});

  Future benchmark(List<Benchmark> benchmarks) {
    if (isCheckedMode()) {
      print('WARNING: You are running in checked mode. Benchmarks should be run'
          ' in unchecked,\nnon-debug mode. I.e., run this from the command-line,'
          ' not the Editor.');
      print('(see also www.dartlang.org/articles/benchmarking)');
      print('');
    }

    log('Running ${benchmarks.length} benchmarks.');
    log('');

    List<BenchMarkResult> results = [];

    return Future.forEach(benchmarks, (benchmark) {
      return benchmarkSingle(benchmark).then((result) {
        results.add(result);
      });
    }).then((_) {
      if (json) {
        print(JSON.encode(results.map(
            (r) => {r.benchmark.name: r.averageMilliseconds()}).toList()));
      }
    });
  }

  Future<BenchMarkResult> benchmarkSingle(Benchmark benchmark) {
    return _warmup(benchmark).then((_) {
      return _measure(benchmark);
    }).then((BenchMarkResult result) {
      logResult(result);
      return result;
    }).whenComplete(() {
      return benchmark.tearDown().catchError((e) => null);
    });
  }

  void log(String message) {
    if (!json) print(message);
  }

  void logResult(BenchMarkResult result) {
    if (!json) print(result);
  }

  Future _warmup(Benchmark benchmark) {
    return _time(benchmark, 2, 1000);
  }

  Future<BenchMarkResult> _measure(Benchmark benchmark) {
    return _time(benchmark, 10, 2000, 10000);
  }

  Future<BenchMarkResult> _time(Benchmark benchmark,
      int minIterations, int minMillis, [int maxMillis]) {
    BenchMarkResult result = new BenchMarkResult(benchmark);
    Stopwatch timer = new Stopwatch()..start();

    return Future.doWhile(() {
      if (result.iteration >= minIterations && timer.elapsedMilliseconds >= minMillis) {
        return false;
      }

      if (maxMillis != null && timer.elapsedMilliseconds >= maxMillis) {
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

  double averageMilliseconds() => (microseconds / iteration) / 1000.0;

  //double _averageMicroseconds() => microseconds / iteration;

  String toString() => '[${benchmark.name.padRight(20)}: '
      '${averageMilliseconds().toStringAsFixed(3).padLeft(8)}ms]';
}

bool isCheckedMode() {
  try {
    String result = "foo";
    result = result + "bar";
    result = _intVal;
    return false;
  } catch (e) {
    return true;
  }
}

dynamic get _intVal => 1 + 2;
