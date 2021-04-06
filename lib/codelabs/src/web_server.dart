import 'package:http/http.dart' as http;

import 'fetcher_impl.dart';

class WebServerCodelabFetcher extends CodelabFetcherImpl {
  final Uri uri;

  WebServerCodelabFetcher(this.uri);

  @override
  Future<String> loadFileContents(List<String> relativePath) async {
    var fileUri =
        uri.replace(pathSegments: [...uri.pathSegments, ...relativePath]);
    var response = await http.get(fileUri);
    return response.body;
  }
}
