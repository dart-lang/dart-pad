import 'codelab.dart';
import 'fetcher.dart';

class WebServerCodelabFetcher implements CodelabFetcher {
  final Uri uri;

  WebServerCodelabFetcher(this.uri);

  @override
  Future<Codelab> getCodelab() async {
    var meta = await _fetchMeta();


    return Codelab('Example codelab', []);
  }

  Future<String> _fetchMeta() async {
    return 'meta.yaml';
  }
}