// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// ignore_for_file: always_specify_types

library services.bench_test;

import 'dart:async';

import 'package:dart_services/src/bench.dart';
import 'package:test/test.dart';

void main() => defineTests();

void defineTests() {
  group('BenchmarkHarness', () {
    test('single', () {
      BenchmarkHarness harness = BenchmarkHarness(asJson: true);
      MockBenchmark benchmark = MockBenchmark();

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
          BenchmarkHarness(asJson: true, logger: (_) => null);
      List<MockBenchmark> benchmarks = [MockBenchmark(), MockBenchmark()];

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

  @override
  Future perform() {
    count++;
    return Future.delayed(Duration(milliseconds: 10));
  }
}
