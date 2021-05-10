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

  Future<List<Step>> fetchSteps(Meta metadata) async {
    // Fetch each step in parallel and place the results in the original order.
    var futures = <Future<Step>>[];
    for (var i = 0; i < metadata.steps.length; i++) {
      var config = metadata.steps[i];
      futures.add(fetchStep(config));
    }
    return Future.wait(futures);
  }

  Future<Step> fetchStep(StepConfiguration config) async {
    var directory = config.directory;
    String instructions;
    String snippet;
    String /*?*/ solution;

    var futures = <Future<String>>[];

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
