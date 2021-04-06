import 'package:meta/meta.dart';

import 'codelab.dart';
import 'fetcher.dart';

class GithubCodelabFetcher implements CodelabFetcher {
  final String owner;
  final String repo;
  final String ref;
  final String path;

  GithubCodelabFetcher({
    @required this.owner,
    @required this.repo,
    @required this.ref,
    @required this.path,
  });

  @override
  Future<Codelab> getCodelab() async {
    throw UnsupportedError('Github codelabs are not supported yet.');
  }
}
