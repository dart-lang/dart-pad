import 'dart:collection';

import 'package:checked_yaml/checked_yaml.dart';

import 'fetcher.dart';
import 'meta.dart';
import 'step.dart';
import 'workshop.dart';

abstract class WorkshopFetcherImpl implements WorkshopFetcher {
  Future<String> loadFileContents(List<String> relativePath);

  @override
  Future<Workshop> fetch() async {
    var metadata = await fetchMeta();
    var steps = await fetchSteps(metadata);
    return Workshop(metadata.name, metadata.type, steps);
  }

  Future<Meta> fetchMeta() async {
    var contents = await loadFileContents(['meta.yaml']);
    return checkedYamlDecode(contents, (Map m) => Meta.fromJson(m));
  }

  Future<Iterable<Step>> fetchSteps(Meta metadata) async {
    // The unnamed list constructor was removed in Dart 2.12, so use a map
    // instead of a list to fetch each step in parallel and place the results in
    // the original order.
    var map = <int, Step>{};
    var futures = <Future>[];
    for (var i = 0; i < metadata.steps.length; i++) {
      var config = metadata.steps[i];
      var future = fetchStep(config).then((step) => map[i] = step);
      futures.add(future);
    }
    await Future.wait(futures);

    // Return the fetched step objects in the same order that they appeared in
    // the configuration metadata
    return List<Step>.generate(metadata.steps.length, (idx) => map[idx]);
  }

  Future<Step> fetchStep(StepConfiguration config) async {
    var directory = config.directory;
    String instructions;
    String snippet;
    String /*?*/ solution;

    var futures = <Future>[];

    futures.add(loadFileContents([directory, 'instructions.md'])
        .then((e) => instructions = e));
    futures.add(
        loadFileContents([directory, 'snippet.dart']).then((e) => snippet = e));

    if (config.hasSolution) {
      futures.add(loadFileContents([directory, 'solution.dart'])
          .then((e) => solution = e));
    }

    await Future.wait(futures);

    return Step(config.name, instructions, snippet, solution: solution);
  }
}
