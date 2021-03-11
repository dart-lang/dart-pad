import 'dart:convert';
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
    print('metadata: $metadata');
    var steps = await _fetchSteps(metadata);

    return Codelab('Example codelab', []);
  }

  Future<Meta> _fetchMeta() async {
    var metadataUri =
        uri.replace(pathSegments: [...uri.pathSegments, 'meta.yaml']);
    var response = await http.get(metadataUri);
    return checkedYamlDecode(response.body, (Map m) => Meta.fromJson(m));
  }

  Future<List<Step>> _fetchSteps(Meta metadata) async {
    return [];
  }
}
