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
  task('discovery', discovery, ['init']);
  task('travis-bench', travisBench, ['init']);
  task('clean', defaultClean);

  startGrinder(args);
}

/**
 * Generate the discovery doc from the annotated API.
 */
Future discovery(GrinderContext context) async {
  context.log('starting Dart Services server.');
  Process process = await Process.start('dart', ['bin/services.dart', '--port=9090']);

  await new Future.delayed(new Duration(milliseconds: 300));

  HttpClientRequest request = await new HttpClient().get(
        'localhost', 9090, 'api/discovery/v1/apis/dartservices/v1/rest');
  HttpClientResponse response = await request.close();
  List<List<int>> data = await response.toList();
  List<int> list = data.reduce((l1, l2) => l1.addAll(l2));
  String contents = new String.fromCharCodes(list);

  File discoveryFile = new File('doc/dartservices.json');
  context.log('writing ${discoveryFile.path}');
  discoveryFile.writeAsStringSync(contents);

  context.log('closing Dart Services server');
  process.kill();
}

/**
 * Run the benchmarks on the build-bot; upload the data to librato.com.
 */
travisBench(GrinderContext context) {
  context.log('Running benchmarks...');

  Librato librato = new Librato.fromEnvVars();
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
