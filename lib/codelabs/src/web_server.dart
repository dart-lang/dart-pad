import 'package:checked_yaml/checked_yaml.dart';
import 'package:http/http.dart' as http;

import 'codelab.dart';
import 'fetcher.dart';
import 'meta.dart';
import 'step.dart';

class WebServerCodelabFetcher implements CodelabFetcher {
  final Uri uri;

  WebServerCodelabFetcher(this.uri);

  @override
  Future<Codelab> getCodelab() async {
    var metadata = await _fetchMeta();
    var steps = await _fetchSteps(metadata);

    return Codelab('Example codelab', metadata.type, steps);
  }

  Future<Meta> _fetchMeta() async {
    var contents = await _loadFileContents(['meta.yaml']);
    return checkedYamlDecode(contents, (Map m) => Meta.fromJson(m));
  }

  Future<List<Step>> _fetchSteps(Meta metadata) async {
    var steps = <Step>[];
    for (var stepConfig in metadata.steps) {
      steps.add(await _fetchStep(stepConfig));
    }
    return steps;
  }

  Future<Step> _fetchStep(StepConfiguration config) async {
    var directory = config.directory;
    var instructions = await _loadFileContents([directory, 'instructions.md']);
    var snippet = await _loadFileContents([directory, 'snippet.dart']);
    var solution = config.hasSolution
        ? await _loadFileContents([directory, 'solution.dart'])
        : null;
    return Step(config.name, instructions, snippet, solution: solution);
  }

  Future<String> _loadFileContents(List<String> relativePath) async {
    var fileUri =
        uri.replace(pathSegments: [...uri.pathSegments, ...relativePath]);
    var response = await http.get(fileUri);
    return response.body;
  }
}
