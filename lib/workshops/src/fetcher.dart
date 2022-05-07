import 'github.dart';
import 'web_server.dart';
import 'workshop.dart';

abstract class WorkshopFetcher {
  /// id to uniquely identify this workshop
  String get workshopId;

  Future<Workshop> fetch();

  factory WorkshopFetcher.github({
    required String owner,
    required String repo,
    String? ref,
    String? path,
  }) =>
      GithubWorkshopFetcher(owner: owner, repo: repo, path: path, ref: ref);

  factory WorkshopFetcher.webserver(Uri uri) => WebServerWorkshopFetcher(uri);
}
