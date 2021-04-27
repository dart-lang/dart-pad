import 'package:dart_pad/codelabs/codelabs.dart';
import 'package:meta/meta.dart';

abstract class CodelabFetcher {
  Future<Codelab> getCodelab();
  factory CodelabFetcher.github({
    @required String owner,
    @required String repo,
    String ref,
    String path,
  }) =>
      GithubCodelabFetcher(owner: owner, repo: repo, path: path, ref: ref);
  factory CodelabFetcher.webserver(Uri uri) => WebServerCodelabFetcher(uri);
}
