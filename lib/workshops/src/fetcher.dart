// @dart=2.9

import 'package:meta/meta.dart';

import 'github.dart';
import 'web_server.dart';
import 'workshop.dart';

abstract class WorkshopFetcher {
  Future<Workshop> fetch();

  factory WorkshopFetcher.github({
    @required String owner,
    @required String repo,
    String ref,
    String path,
  }) =>
      GithubWorkshopFetcher(owner: owner, repo: repo, path: path, ref: ref);

  factory WorkshopFetcher.webserver(Uri uri) => WebServerWorkshopFetcher(uri);
}
