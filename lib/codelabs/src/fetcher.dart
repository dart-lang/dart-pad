import 'package:dart_pad/codelabs/codelabs.dart';
import 'package:meta/meta.dart';

import 'codelab.dart';
import 'github.dart';

abstract class CodelabFetcher {
  Future<Codelab> getCodelab();
  factory CodelabFetcher.github({
    @required String owner,
    @required String repo,
    String ref,
    String path,
  }) => GithubCodelabFetcher(owner: owner, repo: repo, path: path, ref: ref);
  factory CodelabFetcher.webserver(Uri uri) => WebServerCodelabFetcher(uri);
}
