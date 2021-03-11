import 'package:dart_pad/codelabs/codelabs.dart';
import 'package:dart_pad/util/query_params.dart';

Future main() async {
  var fetcher = await getFetcher();
  print(fetcher.getCodelab());
}

Future<CodelabFetcher> getFetcher() async {
  var webServer = queryParams.webServer;
  if (webServer != null && webServer.isNotEmpty) {
    var uri = Uri.parse(webServer);
    return WebServerCodelabFetcher(uri);
  }
  var ghOwner = queryParams.githubOwner;
  var ghRepo = queryParams.githubRepo;
  var ghRef = queryParams.githubRef;
  var ghPath = queryParams.githubPath;
  if (ghOwner != null &&
      ghOwner.isNotEmpty &&
      ghRepo != null &&
      ghRepo.isNotEmpty &&
      ghRef != null &&
      ghRef.isNotEmpty &&
      ghPath != null &&
      ghPath.isNotEmpty) {
    return GithubCodelabFetcher(
      owner: ghOwner,
      repo: ghRepo,
      ref: ghRef,
      path: ghPath,
    );
  }
  throw ('Invalid parameters provided. Use either "webserver" or '
      '"gh_owner", "gh_repo", "gh_ref", and "gh_path"');
}
