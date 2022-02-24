import 'package:checked_yaml/checked_yaml.dart';

import 'fetcher.dart';
import 'meta.dart';
import 'step.dart';
import 'workshop.dart';

abstract class WorkshopFetcherImpl implements WorkshopFetcher {
  Future<String> loadFileContents(List<String> relativePath);

  @override
  Future<Workshop> fetch() async {
    final metadata = await fetchMeta();
    final steps = await fetchSteps(metadata);
    return Workshop(metadata.name, metadata.type, steps);
  }

  Future<Meta> fetchMeta() async {
    final contents = await loadFileContents(['meta.yaml']);
    return checkedYamlDecode(contents, (Map? m) => Meta.fromJson(m!));
  }

  Future<List<Step>> fetchSteps(Meta metadata) async {
    // Fetch each step in parallel and place the results in the original order.
    final futures = <Future<Step>>[];
    for (var i = 0; i < metadata.steps.length; i++) {
      final config = metadata.steps[i];
      futures.add(fetchStep(config));
    }
    return Future.wait(futures);
  }

  Future<Step> fetchStep(StepConfiguration config) async {
    final directory = config.directory;
    late String instructions;
    late String snippet;
    String? solution;

    final futures = <Future<String>>[];

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
