// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.bench_test;

import 'dart:async';

import 'package:services/src/bench.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('BenchmarkHarness', () {
    test('single', () {
      BenchmarkHarness harness = new BenchmarkHarness(json: true);
      MockBenchmark benchmark = new MockBenchmark();

      return harness.benchmarkSingle(benchmark).then((BenchMarkResult result) {
        expect(result.iteration, greaterThan(1));
        expect(result.microseconds, greaterThan(1));
        expect(result.toString(), isNotNull);
        expect(benchmark.count, greaterThan(80));
        expect(benchmark.toString(), 'mock');
      });
    });

    test('many', () {
      BenchmarkHarness harness =
          new BenchmarkHarness(json: true, logger: (_) => null);
      List<MockBenchmark> benchmarks = [
        new MockBenchmark(),
        new MockBenchmark()
      ];

      return harness.benchmark(benchmarks).then((_) {
        expect(benchmarks[0].count, greaterThan(80));
        expect(benchmarks[1].count, greaterThan(80));
      });
    });
  });
}

class MockBenchmark extends Benchmark {
  int count = 0;

  MockBenchmark() : super('mock');

  Future perform() {
    count++;
    return new Future.delayed(new Duration(milliseconds: 10));
  }
}
