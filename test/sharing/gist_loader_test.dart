import 'dart:convert';

import 'package:dart_pad/sharing/gists.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() => defineTests();

void defineTests() {
  MockClient mockClient;
  MockClient rateLimitedMockClient;

  setUp(() async {
    mockClient = MockClient((request) {
      switch (request.url.toString()) {
        case 'https://api.github.com/gists/12345678901234567890123456789012':
          return Future.value(http.Response(validGist, 200));
        case 'https://api.flutter.dev/snippets/material.AppBar.1.dart':
          return Future.value(http.Response(stableAPIDocSample, 200));
        case 'https://master-api.flutter.dev/snippets/material.AppBar.1.dart':
          return Future.value(http.Response(masterAPIDocSample, 200));
        case 'https://api.github.com/repos/owner/repo/contents/basic/dartpad_metadata.yaml':
          return Future.value(http.Response(basicDartMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/alt_branch/dartpad_metadata.yaml?ref=some_branch':
          return Future.value(http.Response(altBranchMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/invalid/dartpad_metadata.yaml':
          return Future.value(http.Response(invalidMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/missing_files/dartpad_metadata.yaml':
          return Future.value(http.Response(missingFilesMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/missing_mode/dartpad_metadata.yaml':
          return Future.value(http.Response(missingModeMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/missing_name/dartpad_metadata.yaml':
          return Future.value(http.Response(missingNameMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/missing_file/dartpad_metadata.yaml':
          return Future.value(
              http.Response(missingIndividualFileMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/unnecessary_file/dartpad_metadata.yaml':
          return Future.value(http.Response(unnecessaryFileMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/alternate_path/dartpad_metadata.yaml':
          return Future.value(http.Response(alternatePathMetadata, 200));
        case 'https://api.github.com/repos/owner/repo/contents/basic/main.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alt_branch/main.dart?ref=some_branch':
        case 'https://api.github.com/repos/owner/repo/contents/unnecessary_file/main.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alternate_path/main.dart':
          return Future.value(http.Response(mainFileContent, 200));
        case 'https://api.github.com/repos/owner/repo/contents/basic/test.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alt_branch/test.dart?ref=some_branch':
        case 'https://api.github.com/repos/owner/repo/contents/unnecessary_file/test.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alternate_path/a_subfolder/test.dart':
          return Future.value(http.Response(testFileContent, 200));
        case 'https://api.github.com/repos/owner/repo/contents/basic/solution.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alt_branch/solution.dart?ref=some_branch':
        case 'https://api.github.com/repos/owner/repo/contents/unnecessary_file/solution.dart':
        case 'https://api.github.com/repos/owner/repo/contents/alternate_path/solution.dart':
          return Future.value(http.Response(solutionFileContent, 200));
        case 'https://api.github.com/repos/owner/repo/contents/basic/hint.txt':
          return Future.value(http.Response(hintFileContent, 200));
        case 'https://api.github.com/repos/owner/repo/contents/unnecessary_file/unnecessary.txt':
          return Future.value(http.Response(unnecessaryFileContent, 200));
      }

      return Future.value(http.Response('File not found!', 404));
    });

    rateLimitedMockClient = MockClient((request) {
      return Future.value(http.Response('Over the line!', 403));
    });
  });

  group('GistLoader end-to-end tests', () {
    group('Loading by gist ID', () {
      test('Returns valid gist for valid gist id', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGist('12345678901234567890123456789012');
        final contents = gist.files.firstWhere((f) => f.name == 'main.dart');
        expect(contents.content, 'This is some dart code!');
      });
      test('Throws correct exception for nonexistent gist', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGist('12345678901234567890123456789000'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.contentNotFound)));
      });
      test('Throws correct exception for rate limit', () async {
        final loader = GistLoader(client: rateLimitedMockClient);
        expect(
            loader.loadGist('12345678901234567890123456789012'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.rateLimitExceeded)));
      });
    });
    group('Loading by sample ID', () {
      test('Returns stable version gist for stable sample id', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromAPIDocs(
            'material.AppBar.1', FlutterSdkChannel.stable);
        final contents = gist.files.firstWhere((f) => f.name == 'main.dart');
        expect(contents.content, stableAPIDocSample);
      });
      test('Returns master version gist for master sample id', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromAPIDocs(
            'material.AppBar.1', FlutterSdkChannel.master);
        final contents = gist.files.firstWhere((f) => f.name == 'main.dart');
        expect(contents.content, masterAPIDocSample);
      });
      test('Throws correct exception for nonexistent sample', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGist('material.WunderWidget.1'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.contentNotFound)));
      });
      test('Throws correct exception for rate limit', () async {
        final loader = GistLoader(client: rateLimitedMockClient);
        expect(
            loader.loadGist('material.AppBar.1'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.rateLimitExceeded)));
      });
    });
    group('Loading from Repo', () {
      test('Returns valid gist for valid repo info', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromRepo(
            owner: 'owner', repo: 'repo', path: 'basic');
        final contents = gist.files.firstWhere((f) => f.name == 'main.dart');
        expect(contents.content, 'this is main.dart');
      });
      test('Returns valid gist for alternate branch', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromRepo(
            owner: 'owner',
            repo: 'repo',
            path: 'alt_branch',
            ref: 'some_branch');
        final contents = gist.files.firstWhere((f) => f.name == 'main.dart');
        expect(contents.content, 'this is main.dart');
      });
      test('Throws exception for invalid metadata', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'invalid'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType ==
                GistLoaderFailureType.invalidExerciseMetadata)));
      });
      test('Throws correct for metadata missing files propery', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'missing_files'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType ==
                GistLoaderFailureType.invalidExerciseMetadata)));
      });
      test('Throws exception for metadata missing name', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'missing_name'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType ==
                GistLoaderFailureType.invalidExerciseMetadata)));
      });
      test('Throws exception for metadata missing mode', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'missing_mode'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType ==
                GistLoaderFailureType.invalidExerciseMetadata)));
      });
      test('Throws exception for metadata with invalid file path', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'missing_file'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType ==
                GistLoaderFailureType.invalidExerciseMetadata)));
      });
      test('Returns gist with oddly named file included', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromRepo(
            owner: 'owner', repo: 'repo', path: 'unnecessary_file');
        final contents =
            gist.files.firstWhere((f) => f.name == 'unnecessary.txt');
        expect(contents.content, 'this is unnecessary.txt');
      });
      test('Returns gist for metadata with alternate path', () async {
        final loader = GistLoader(client: mockClient);
        final gist = await loader.loadGistFromRepo(
            owner: 'owner', repo: 'repo', path: 'alternate_path');
        final contents = gist.files.firstWhere((f) => f.name == 'test.dart');
        expect(contents.content, 'this is test.dart');
      });
      test('Throws correct exception for incorrect metadata path', () async {
        final loader = GistLoader(client: mockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'does_not_exist'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.contentNotFound)));
      });
      test('Throws correct exception when rate limited', () async {
        final loader = GistLoader(client: rateLimitedMockClient);
        expect(
            loader.loadGistFromRepo(
                owner: 'owner', repo: 'repo', path: 'basic'),
            throwsA(predicate<GistLoaderException>((e) =>
                e.failureType == GistLoaderFailureType.rateLimitExceeded)));
      });
    });
  });
}

final validGist = '''
{
  "url": "https://api.github.com/gists/04b97ad82c9779d49683045f3b75bdba",
  "forks_url": "https://api.github.com/gists/04b97ad82c9779d49683045f3b75bdba/forks",
  "commits_url": "https://api.github.com/gists/04b97ad82c9779d49683045f3b75bdba/commits",
  "id": "04b97ad82c9779d49683045f3b75bdba",
  "node_id": "MDQ6R2lzdDA0Yjk3YWQ4MmM5Nzc5ZDQ5NjgzMDQ1ZjNiNzViZGJh",
  "git_pull_url": "https://gist.github.com/04b97ad82c9779d49683045f3b75bdba.git",
  "git_push_url": "https://gist.github.com/04b97ad82c9779d49683045f3b75bdba.git",
  "html_url": "https://gist.github.com/04b97ad82c9779d49683045f3b75bdba",
  "files": {
    "main.dart": {
      "filename": "main.dart",
      "type": "application/vnd.dart",
      "language": "Dart",
      "raw_url": "https://gist.githubusercontent.com/RedBrogdon/04b97ad82c9779d49683045f3b75bdba/raw/4efa8efa772b952da1123005069758a2e809206c/main.dart",
      "size": 1768,
      "truncated": false,
      "content": "This is some dart code!"
    }
  },
  "public": true,
  "created_at": "2019-09-19T04:09:27Z",
  "updated_at": "2019-09-19T04:10:01Z",
  "description": "Flutter.dev example 1",
  "comments": 0,
  "user": null,
  "comments_url": "https://api.github.com/gists/04b97ad82c9779d49683045f3b75bdba/comments",
  "owner": {
    "login": "RedBrogdon",
    "id": 969662,
    "node_id": "MDQ6VXNlcjk2OTY2Mg==",
    "avatar_url": "https://avatars3.githubusercontent.com/u/969662?v=4",
    "gravatar_id": "",
    "url": "https://api.github.com/users/RedBrogdon",
    "html_url": "https://github.com/RedBrogdon",
    "followers_url": "https://api.github.com/users/RedBrogdon/followers",
    "following_url": "https://api.github.com/users/RedBrogdon/following{/other_user}",
    "gists_url": "https://api.github.com/users/RedBrogdon/gists{/gist_id}",
    "starred_url": "https://api.github.com/users/RedBrogdon/starred{/owner}{/repo}",
    "subscriptions_url": "https://api.github.com/users/RedBrogdon/subscriptions",
    "organizations_url": "https://api.github.com/users/RedBrogdon/orgs",
    "repos_url": "https://api.github.com/users/RedBrogdon/repos",
    "events_url": "https://api.github.com/users/RedBrogdon/events{/privacy}",
    "received_events_url": "https://api.github.com/users/RedBrogdon/received_events",
    "type": "User",
    "site_admin": false
  },
  "truncated": false
}
''';

final stableAPIDocSample =
    'This is some sample code from the stable API Doc server.';
final masterAPIDocSample =
    'This is some sample code from the master API Doc server.';

/// Create a GitHub API-like contents response for the provided content.
String _createContentsJson(String content) {
  return '''
{
  "name": "this name does not matter",
  "path": "this does not matter either",
  "sha": "24e191ed740c5a1835785281ff118f0d3a605596",
  "size": 9396,
  "url": "https://api.github.com/repos/RedBrogdon/flutterflip/contents/lib/main.dart?ref=master",
  "html_url": "https://github.com/RedBrogdon/flutterflip/blob/master/lib/main.dart",
  "git_url": "https://api.github.com/repos/RedBrogdon/flutterflip/git/blobs/24e191ed740c5a1835785281ff118f0d3a605596",
  "download_url": "https://raw.githubusercontent.com/RedBrogdon/flutterflip/master/lib/main.dart",
  "type": "file",
  "content": "${base64.encode(utf8.encode(content))}",
  "encoding": "base64",
  "_links": {
    "self": "https://api.github.com/repos/RedBrogdon/flutterflip/contents/lib/main.dart?ref=master",
    "git": "https://api.github.com/repos/RedBrogdon/flutterflip/git/blobs/24e191ed740c5a1835785281ff118f0d3a605596",
    "html": "https://github.com/RedBrogdon/flutterflip/blob/master/lib/main.dart"
  }
}
''';
}

final basicDartMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
  - name: hint.txt
''');

final altBranchMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
''');

final invalidMetadata = _createContentsJson('''
There should be valid YAML in this file but there's not.
Golly, I hope that doesn't cause an error!
''');

final missingFilesMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
''');

final missingModeMetadata = _createContentsJson('''
name: A Dart Exercise
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
  - name: hint.txt
''');

final missingNameMetadata = _createContentsJson('''
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
  - name: hint.txt
''');

final missingIndividualFileMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
  - name: hint.txt
''');

final unnecessaryFileMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
  - name: unnecessary.txt
''');

final alternatePathMetadata = _createContentsJson('''
name: A Dart Exercise
mode: dart
files:
  - name: main.dart
  - name: solution.dart
  - name: test.dart
    alternatePath: a_subfolder/test.dart
''');

final mainFileContent = _createContentsJson('this is main.dart');

final testFileContent = _createContentsJson('this is test.dart');

final solutionFileContent = _createContentsJson('this is solution.dart');

final hintFileContent = _createContentsJson('this is hint.txt');

final unnecessaryFileContent = _createContentsJson('this is unnecessary.txt');
