import 'package:http/http.dart' as http;

import 'fetcher_impl.dart';

class WebServerWorkshopFetcher extends WorkshopFetcherImpl {
  final Uri uri;

  WebServerWorkshopFetcher(this.uri);

  @override
  Future<String> loadFileContents(List<String> relativePath) async {
    final fileUri =
        uri.replace(pathSegments: [...uri.pathSegments, ...relativePath]);
    final response = await http.get(fileUri);
    return response.body;
  }

  @override
  String get workshopId => 'webserverworkshop-$uri';
}
