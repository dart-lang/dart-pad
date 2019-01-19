// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

/// A benchmark library. This library supports running benchmarks which can
/// run asynchronously.
library services.bench;

import 'dart:async';
import 'dart:convert' show json;

abstract class Benchmark {
  final String name;

  Benchmark(this.name);

  Future init() => Future.value();

  Future perform();

  /// Called once when this benchmark will no longer be used.
  Future tearDown() => Future.value();

  @override
  String toString() => name;
}

typedef BenchmarkLogger = void Function(String str);

class BenchmarkHarness {
  final bool asJson;
  final BenchmarkLogger logger;

  BenchmarkHarness({this.asJson, this.logger = print});

  Future benchmark(List<Benchmark> benchmarks) async {
    if (isCheckedMode()) {
      logger(
          'WARNING: You are running in checked mode. Benchmarks should be run in unchecked,\n'
          'non-debug mode. See also www.dartlang.org/articles/benchmarking.\n');
    }

    log('Running ${benchmarks.length} benchmarks.');
    log('');

    List<BenchMarkResult> results = [];

    await Future.forEach(benchmarks, (Benchmark benchmark) => benchmark.init());

    return Future.forEach(benchmarks, (benchmark) {
      return benchmarkSingle(benchmark).then((result) {
        results.add(result);
      });
    }).then((_) {
      if (asJson) {
        logger(json.encode(results
            .map((r) => {r.benchmark.name: r.averageMilliseconds()})
            .toList()));
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
    if (!asJson) logger(message);
  }

  void logResult(BenchMarkResult result) {
    if (!asJson) logger(result.toString());
  }

  Future _warmup(Benchmark benchmark) {
    return _time(benchmark, 2, 1000);
  }

  Future<BenchMarkResult> _measure(Benchmark benchmark) {
    return _time(benchmark, 10, 2000, 10000);
  }

  Future<BenchMarkResult> _time(
      Benchmark benchmark, int minIterations, int minMillis,
      [int maxMillis]) {
    BenchMarkResult result = BenchMarkResult(benchmark);
    Stopwatch timer = Stopwatch()..start();

    return Future.doWhile(() {
      if (result.iteration >= minIterations &&
          timer.elapsedMilliseconds >= minMillis) {
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

  @override
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
