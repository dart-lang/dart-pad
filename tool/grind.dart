// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.grind;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:io';

import 'package:grinder/grinder.dart';
import 'package:librato/librato.dart';

void main(List<String> args) {
  task('init', defaultInit);
  task('travis-bench', travisBench, ['init']);
  task('clean', defaultClean);

  startGrinder(args);
}

/**
 * Run the benchmarks on the build-bot; upload the data to librato.com.
 */
travisBench(GrinderContext context) {
  Librato librato;

  try {
    librato = new Librato.fromEnvVars();
  } catch (e) {
    // If there's no librato auth info set, don't try and uplaod the stats data.
    return new Future.value();
  }

  context.log('Running benchmarks...');

  if (Platform.environment['TRAVIS_COMMIT'] == null) {
    context.fail('Missing env var: TRAVIS_COMMIT');
  }

  ProcessResult result = Process.runSync(
      'dart', ['benchmark/bench.dart', '--json']);
  if (result.exitCode != 0) {
    context.fail('benchmarks exit code: ${result.exitCode}');
  }

  List results = JSON.decode(result.stdout);
  List<LibratoStat> stats = [];

  results.forEach((Map result) {
    context.log('${result}');

    String key = result.keys.first;
    stats.add(new LibratoStat(key, result[key]));
  });

  context.log('Uploading stats to ${librato.baseUrl}');
  context.log('${stats}');

  return librato.postStats(stats).then((_) {
    String commit = Platform.environment['TRAVIS_COMMIT'];
    LibratoLink link = new LibratoLink(
        'github',
        'https://github.com/dart-lang/dart-services/commit/${commit}');
    LibratoAnnotation annotation = new LibratoAnnotation(
        commit,
        description: 'Commit ${commit}',
        links: [link]);
    return librato.createAnnotation('build_server', annotation);
  });
}
