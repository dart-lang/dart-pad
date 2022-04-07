// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:convert';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:fluttering_phrases/fluttering_phrases.dart' as phrases;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart' as yaml;

import '../src/sample.dart' as sample;
import '../util/detect_flutter.dart' as detect_flutter;
import '../util/github.dart';
import 'exercise_metadata.dart';

final String _dartpadLink = '[dartpad.dev](https://dartpad.dev)';

final RegExp _gistRegex = RegExp(r'^[0-9a-f]+$');

enum FlutterSdkChannel {
  master,
  beta,
  stable,
}

/// Return whether the given string is a valid github gist ID.
bool isLegalGistId(String? id) {
  if (id == null || id.isEmpty) return false;
  // 4/8/2016: Github gist ids changed from 20 to 32 characters long.
  return _gistRegex.hasMatch(id) && id.length >= 5 && id.length <= 40;
}

/// Given either partial html text, or a full html document, extract out the
/// `<body>` tag.
String? extractHtmlBody(String? html) {
  if (html == null || !html.contains('<html')) {
    return html;
  } else {
    final body = r'body(?:\s[^>]*)?'; // Body tag with its attributes
    final any = r'[\s\S]'; // Any character including new line
    final bodyRegExp = RegExp('<$body>($any*)</$body>(?:(?!</$body>)$any)*',
        multiLine: true, caseSensitive: false);
    final match = bodyRegExp.firstMatch(html);
    return match == null ? '' : match.group(1)!.trim();
  }
}

Gist createSampleDartGist() {
  final description = phrases.generate();
  final gist = Gist(description: description, files: [
    GistFile(name: 'main.dart', content: sample.dartCode),
    GistFile(
        name: 'readme.md',
        content:
            _createReadmeContents(title: description, withLink: _dartpadLink)),
  ]);
  return gist;
}

Gist createSampleHtmlGist() {
  final description = phrases.generate();
  final gist = Gist(description: description, files: [
    GistFile(name: 'main.dart', content: sample.dartCodeHtml),
    GistFile(name: 'index.html', content: sample.htmlCode),
    GistFile(name: 'styles.css', content: sample.cssCode),
    GistFile(
        name: 'readme.md',
        content:
            _createReadmeContents(title: description, withLink: _dartpadLink)),
  ]);
  return gist;
}

Gist createSampleFlutterGist() {
  final description = phrases.generate();
  final gist = Gist(description: description, files: [
    GistFile(name: 'main.dart', content: sample.flutterCode),
    GistFile(
        name: 'readme.md',
        content:
            _createReadmeContents(title: description, withLink: _dartpadLink)),
  ]);
  return gist;
}

/// Find the best match for the given file names in the gist file info; return
/// the file (or `null` if no match is found).
GistFile? chooseGistFile(Gist gist, List<String> names, [Function? matcher]) {
  final files = gist.files;

  for (final name in names) {
    final file = files.firstWhereOrNull((f) => f.name == name);
    if (file != null) return file;
  }

  if (matcher != null) {
    return files.firstWhereOrNull((f) => matcher(f.name) as bool);
  } else {
    return null;
  }
}

typedef GistFilterHook = void Function(Gist gist);

enum GistLoaderFailureType {
  unknown,
  contentNotFound,
  rateLimitExceeded,
  invalidExerciseMetadata,
}

class GistLoaderException implements Exception {
  final GistLoaderFailureType failureType;
  final String? message;

  const GistLoaderException(this.failureType, [this.message]);
}

/// A class to load and save gists. Gists can optionally be modified after
/// loading and before saving.
class GistLoader {
  static const String _gistApiUrl = 'https://api.github.com/gists';
  static const String _repoContentsAuthority = 'api.github.com';
  static const String _metadataFilename = 'dartpad_metadata.yaml';

  static const String _stableApiDocsUrl = 'https://api.flutter.dev/snippets';
  static const String _masterApiDocsUrl =
      'https://master-api.flutter.dev/snippets';

  static void _defaultLoadHook(Gist gist) {
    // Update files based on our preferred file names.
    if (gist.getFile('body.html') != null &&
        gist.getFile('index.html') == null) {
      final file = gist.getFile('body.html')!;
      file.name = 'index.html';
    }

    if (gist.getFile('style.css') != null &&
        gist.getFile('styles.css') == null) {
      final file = gist.getFile('style.css')!;
      file.name = 'styles.css';
    }

    if (gist.getFile('main.dart') == null &&
        gist.files.where((f) => f.name.endsWith('.dart')).length == 1) {
      final file = gist.files.firstWhere((f) => f.name.endsWith('.dart'));
      file.name = 'main.dart';
    }

    // Extract the body out of the html file.
    final htmlFile = gist.getFile('index.html');
    if (htmlFile != null) {
      htmlFile.content = extractHtmlBody(htmlFile.content);
    }
  }

  static void _defaultSaveHook(Gist gist) {
    // Create a full html file on save.
    final hasStyles = gist.getFile('styles.css') != null;
    final styleRef =
        hasStyles ? '    <link rel="stylesheet" href="styles.css">\n' : '';

    final hasDart = gist.getFile('main.dart') != null;
    final dartRef = hasDart
        ? '    <script type="application/dart" src="main.dart"></script>\n'
        : '';

    final htmlFile = gist.getFile('index.html');
    if (htmlFile != null) {
      htmlFile.content = '''
<!DOCTYPE html>

<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${gist.description}</title>
$styleRef$dartRef  </head>

  <body>
    ${htmlFile.content}
  </body>
</html>
''';
    }

    // Update the readme for this gist.
    final readmeFile = GistFile(
        name: 'readme.md',
        content: _createReadmeContents(
            title: gist.description,
            summary: gist.summary,
            withLink: _dartpadLink));
    gist.files.add(readmeFile);
  }

  final GistFilterHook? afterLoadHook;
  final GistFilterHook? beforeSaveHook;
  final http.Client _client;

  GistLoader({
    this.afterLoadHook,
    this.beforeSaveHook,
    http.Client? client,
  }) : _client = client ?? http.Client();

  GistLoader.defaultFilters()
      : this(afterLoadHook: _defaultLoadHook, beforeSaveHook: _defaultSaveHook);

  /// Load the gist with the given id.
  Future<Gist> loadGist(String? gistId) async {
    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    final response = await _client.get(Uri.parse('$_gistApiUrl/$gistId'));

    if (response.statusCode == 404) {
      throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
    } else if (response.statusCode == 403) {
      throw const GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
    } else if (response.statusCode != 200) {
      throw const GistLoaderException(GistLoaderFailureType.unknown);
    }

    final gist =
        Gist.fromMap(json.decode(response.body) as Map<String, dynamic>);

    afterLoadHook?.call(gist);

    return gist;
  }

  /// Load the gist with the given id.
  Future<String> createGist(
      Gist gistToSave, bool public, String authenticationToken) async {
    if (beforeSaveHook != null) beforeSaveHook!(gistToSave);

    /*
      Create a gist
      Allows you to add a new gist with one or more files.

      Note: Don't name your files "gistfile" with a numerical suffix. 
      This is the format of the automatic naming scheme that Gist uses 
      internally.

      POST /gists
      Parameters
      Name        Type    In      Description
      accept      string  header  Setting toapplication/vnd.github.v3+json is recommended.

      description  string body    Description of the gist

      files       object  body    Required. Names and content for the files that make up the gist

      public      boolean body    Flag indicating whether the gist is public     
                  or string
            
      Example Response

      Status: 201 Created
      {
        "url": "https://api.github.com/gists/aa5a315d61ae9438b18d",
        "forks_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/forks",
        "commits_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/commits",
        "id": "aa5a315d61ae9438b18d",
        "node_id": "MDQ6R2lzdGFhNWEzMTVkNjFhZTk0MzhiMThk",
        "git_pull_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
        "git_push_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
        "html_url": "https://gist.github.com/aa5a315d61ae9438b18d",
        "created_at": "2010-04-14T02:15:15Z",
        "updated_at": "2011-06-20T11:34:15Z",
        "description": "Hello World Examples",
        "comments": 0,
        "comments_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/comments/"
      }
    */
    final Map<String, dynamic> map = gistToSave.toMap(); //;
    map.remove('id');
    map['public'] = public;
    if (map['files'] != null) {
      if (map['files']['.metadata.json'] != null) {
        // if it is present then remove metadata json file from gist when saving
        map['files'].remove('.metadata.json');
      }
    }
    final String bodydata = json.encode(map);
    //print(bodydata);

    return _client
        .post(Uri.parse(_gistApiUrl),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
              if (authenticationToken.isNotEmpty)
                'Authorization': 'Bearer $authenticationToken',
            },
            body: bodydata)
        .then((http.Response response) {
      print('createGist() Response status: ${response.statusCode}');
      print('createGist() Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 201) {
        print('CREATION WORKED!');
        final retObj = jsonDecode(response.body);
        print('ID = ${retObj['id']}');
        return retObj['id'] as String;
      } else if (response.statusCode == 404) {
        throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
      return 'FAILED_CREATE_GIST';
    });
  }

  /// Load the gist with the given id.
  Future<String> updateGist(
      Gist gistToUpdate, String authenticationToken) async {
    if (beforeSaveHook != null) beforeSaveHook!(gistToUpdate);

    final String gistId = gistToUpdate.id ?? '';

    /*
      Allows you to update or delete a gist file and rename gist files. Files from the previous version of the gist that aren't explicitly changed during an edit are unchanged.

      PATCH /gists/{gist_id}
      Parameters
      Name         Type      In       Description
      accept      string   header    Setting toapplication/vnd.github.v3+json is recommended.
      gist_id     string   path      gist_id parameter
      description string   body      Description of the gist
      files       object   body      Names of files to be update
    */
    final Map<String, dynamic> map = gistToUpdate.toMap(); //;
    map.remove('id');
    map.remove('public');
    final String bodydata = json.encode(map);
    print(bodydata);

    return _client
        .patch(Uri.parse('$_gistApiUrl/$gistId'),
            headers: {
              'Accept': 'application/vnd.github.v3+json',
              'Content-Type': 'application/json',
              if (authenticationToken.isNotEmpty)
                'Authorization': 'Bearer $authenticationToken',
            },
            body: bodydata)
        .then((http.Response response) {
      print('updateGist() Response status: ${response.statusCode}');
      print('updateGist() Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 200) {
        /* example return
                {
                  "url": "https://api.github.com/gists/aa5a315d61ae9438b18d",
                  "forks_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/forks",
                  "commits_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/commits",
                  "id": "aa5a315d61ae9438b18d",
                  "node_id": "MDQ6R2lzdGFhNWEzMTVkNjFhZTk0MzhiMThk",
                  "git_pull_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
                  "git_push_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
                  "html_url": "https://gist.github.com/aa5a315d61ae9438b18d",
                  "created_at": "2010-04-14T02:15:15Z",
                  "updated_at": "2011-06-20T11:34:15Z",
                  "description": "Hello World Examples",
                  "comments": 0,
                  "comments_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/comments/"
                }
              */
        print('update succeeded!');
        final retObj = jsonDecode(response.body);
        print('ID = ${retObj['id']}');
        return retObj['id'] as String;
      } else if (response.statusCode == 404) {
        return 'GIST_NOT_FOUND';
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
      return 'FAILED_TO_UPDATE';
    });
  }

  /// Load the gist with the given id.
  Future<String> forkGist(Gist gistToSave, bool localUnsavedEdits, String authenticationToken) async {
    if (beforeSaveHook != null) beforeSaveHook!(gistToSave);

    final String gistId = gistToSave.id ?? '';
    if (gistId.isEmpty) {
      // we have no gistId to fork from, so SAVE instead
      return createGist(gistToSave, gistToSave.public, authenticationToken);
    }

    /*
      POST /gists/{gist_id}/forks
      Parameters
      Name       Type       In       Description
      accept    string   header     Setting toapplication/vnd.github.v3+json is recommended.
      gist_id    string   path       gist_id parameter
    */
    return _client.post(
      Uri.parse('$_gistApiUrl/$gistId/forks'),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
        if (authenticationToken.isNotEmpty)
          'Authorization': 'Bearer $authenticationToken',
      },
      //body:bodydata
    ).then((http.Response response) {
      print('forkGist() Response status: ${response.statusCode}');
      print('forkGist() Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 201) {
        /* example return
       {
          "url": "https://api.github.com/gists/aa5a315d61ae9438b18d",
          "forks_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/forks",
          "commits_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/commits",
          "id": "aa5a315d61ae9438b18d",
          "node_id": "MDQ6R2lzdGFhNWEzMTVkNjFhZTk0MzhiMThk",
          "git_pull_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
          "git_push_url": "https://gist.github.com/aa5a315d61ae9438b18d.git",
          "html_url": "https://gist.github.com/aa5a315d61ae9438b18d",
          "files": {
            "hello_world.rb": {
              "filename": "hello_world.rb",
              "type": "application/x-ruby",
              "language": "Ruby",
              "raw_url": "https://gist.githubusercontent.com/octocat/6cad326836d38bd3a7ae/raw/db9c55113504e46fa076e7df3a04ce592e2e86d8/hello_world.rb",
              "size": 167
            }
          },
          "public": true,
          "created_at": "2010-04-14T02:15:15Z",
          "updated_at": "2011-06-20T11:34:15Z",
          "description": "Hello World Examples",
          "comments": 0,
          "user": null,
          "comments_url": "https://api.github.com/gists/aa5a315d61ae9438b18d/comments/",
          "owner": {
            "login": "octocat",
            "id": 1,
            "node_id": "MDQ6VXNlcjE=",
            "avatar_url": "https://github.com/images/error/octocat_happy.gif",
            "gravatar_id": "",
            "url": "https://api.github.com/users/octocat",
            "html_url": "https://github.com/octocat",
            "followers_url": "https://api.github.com/users/octocat/followers",
            "following_url": "https://api.github.com/users/octocat/following{/other_user}",
            "gists_url": "https://api.github.com/users/octocat/gists{/gist_id}",
            "starred_url": "https://api.github.com/users/octocat/starred{/owner}{/repo}",
            "subscriptions_url": "https://api.github.com/users/octocat/subscriptions",
            "organizations_url": "https://api.github.com/users/octocat/orgs",
            "repos_url": "https://api.github.com/users/octocat/repos",
            "events_url": "https://api.github.com/users/octocat/events{/privacy}",
            "received_events_url": "https://api.github.com/users/octocat/received_events",
            "type": "User",
            "site_admin": false
          },
          "truncated": false
        }
      */
        print('FORKING WORKED!');
        final retObj = jsonDecode(response.body);
        print('Fork ID = ${retObj['id']}');
        final String forkedGistId = retObj['id'] as String;

        if(localUnsavedEdits) {
          // There were UNSAVED local edits, so we also need to now
          // UDPATE this new fork with those edits
          final Gist forkedGist = gistToSave.cloneWithNewId(forkedGistId);
          return updateGist(forkedGist,authenticationToken);
        }
        return forkedGistId;
      } else if (response.statusCode == 422) {
        return 'GIST_ALREADY_FORK';
      } else if (response.statusCode == 404) {
        return 'GIST_NOT_FOUND';
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 200) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
      return 'FAILED_TO_FORK';
    });
  }

  /// Check to see if the user has starred the gist with the specified ID
  Future<bool> checkIfGistIsStarred(
      String gistIdToCheck, String authenticationToken) async {
    /*
        Check if a gist is starred

        GET /gists/{gist_id}/star

        Parameters
        Name       Type      In     Description
        accept    string    header  Setting toapplication/vnd.github.v3+json is recommended.
        gist_id   string    path    gist_id parameter


        Response Status codes
        HTTP Status Code        Description
            204                 Response if gist is starred
            404                 Not Found if gist is not starred
            304                 Not modified
            403                 Forbidden

       https://docs.github.com/en/rest/reference/gists#check-if-a-gist-is-starred
    */
    return _client.get(
      Uri.parse('$_gistApiUrl/$gistIdToCheck/star'),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        if (authenticationToken.isNotEmpty)
          'Authorization': 'Bearer $authenticationToken',
      },
    ).then((http.Response response) {
      print('checkIfGistIsStarred Response status: ${response.statusCode}');
      print('checkIfGistIsStarred Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        return false;
      } else if (response.statusCode == 304) {
        return false; // not modified
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
    });
  }

  /// Star the specified gist for the user
  Future<bool> starGist(String gistIdToStar, String authenticationToken) async {
    /*
        Star the gist

        PUT /gists/{gist_id}/star

        Parameters
        Name       Type      In     Description
        accept    string    header  Setting toapplication/vnd.github.v3+json is recommended.
        gist_id   string    path    gist_id parameter


        Response Status codes
        HTTP Status Code        Description
            204                 No Content (it worked)
            404                 Not Found if gist is not starred
            304                 Not modified
            403                 Forbidden

       https://docs.github.com/en/rest/reference/gists#check-if-a-gist-is-starred
    */
    return _client.put(
      Uri.parse('$_gistApiUrl/$gistIdToStar/star'),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        if (authenticationToken.isNotEmpty)
          'Authorization': 'Bearer $authenticationToken',
      },
    ).then((http.Response response) {
      print('starGist Response status: ${response.statusCode}');
      print('starGist Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        // Gist not found
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 304) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
      return false;
    });
  }

  /// Unstar the specified gist for the user
  Future<bool> unstarGist(
      String gistIdToStar, String authenticationToken) async {
    /*
        Star the gist

        DELETE /gists/{gist_id}/star

        Parameters
        Name       Type      In     Description
        accept    string    header  Setting toapplication/vnd.github.v3+json is recommended.
        gist_id   string    path    gist_id parameter


        Response Status codes
        HTTP Status Code        Description
            204                 No Content (it worked)
            404                 Not Found if gist is not starred
            304                 Not modified
            403                 Forbidden

       https://docs.github.com/en/rest/reference/gists#check-if-a-gist-is-starred
    */
    return _client.delete(
      Uri.parse('$_gistApiUrl/$gistIdToStar/star'),
      headers: {
        'Accept': 'application/vnd.github.v3+json',
        if (authenticationToken.isNotEmpty)
          'Authorization': 'Bearer $authenticationToken',
      },
    ).then((http.Response response) {
      print('unstarGist Response status: ${response.statusCode}');
      print('unstarGist Response body: ${response.contentLength}');
      print(response.headers);
      print(response.request);
      if (response.statusCode == 204) {
        return true;
      } else if (response.statusCode == 404) {
        // Gist not found
      } else if (response.statusCode == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else if (response.statusCode != 304) {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
      return false;
    });
  }

  Future<Gist> loadGistFromAPIDocs(
      String sampleId, FlutterSdkChannel channel) async {
    if (channel == FlutterSdkChannel.beta) {
      throw ArgumentError('Only stable and master channels are supported!');
    }

    final sampleUrl = (channel == FlutterSdkChannel.master)
        ? '$_masterApiDocsUrl/$sampleId.dart'
        : '$_stableApiDocsUrl/$sampleId.dart';

    final response = await _client.get(Uri.parse(sampleUrl));

    if (response.statusCode == 404) {
      throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
    } else if (response.statusCode == 403) {
      throw const GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
    } else if (response.statusCode != 200) {
      throw const GistLoaderException(GistLoaderFailureType.unknown);
    }

    final mainFile = GistFile(
      name: 'main.dart',
      content: response.body,
    );

    final gist = Gist(files: [mainFile]);

    afterLoadHook?.call(gist);

    return gist;
  }

  Uri _buildContentsUrl(String owner, String repo, String path, [String? ref]) {
    return Uri.https(
      _repoContentsAuthority,
      'repos/$owner/$repo/contents/$path',
      (ref?.isNotEmpty == true) ? {'ref': ref} : null,
    );
  }

  Future<Gist> loadGistFromRepo({
    required String owner,
    required String repo,
    required String path,
    String? ref,
  }) async {
    // Download and parse the exercise's `dartpad_metadata.json` file.
    final metadataUrl =
        _buildContentsUrl(owner, repo, '$path/$_metadataFilename', ref);
    final metadataResponse = await _client.get(metadataUrl);

    if (metadataResponse.statusCode == 404) {
      throw GistLoaderException(GistLoaderFailureType.contentNotFound);
    } else if (metadataResponse.statusCode == 403) {
      throw GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
    } else if (metadataResponse.statusCode != 200) {
      throw GistLoaderException(GistLoaderFailureType.unknown);
    }

    final metadataContent = extractGitHubResponseBody(metadataResponse.body);

    final ExerciseMetadata metadata;

    try {
      final yamlMap = yaml.loadYaml(metadataContent);

      if (yamlMap is! Map) {
        throw FormatException();
      }

      metadata = ExerciseMetadata.fromMap(yamlMap);
    } on MetadataException catch (ex) {
      throw GistLoaderException(GistLoaderFailureType.invalidExerciseMetadata,
          'Issue parsing metadata: $ex');
    } on FormatException catch (ex) {
      throw GistLoaderException(GistLoaderFailureType.invalidExerciseMetadata,
          'Issue parsing metadata: $ex');
    }

    // Make additional requests for the files listed in the metadata.
    final requests = metadata.files.map((file) async {
      final contentUrl =
          _buildContentsUrl(owner, repo, '$path/${file.path}', ref);
      final contentResponse = await _client.get(contentUrl);

      if (contentResponse.statusCode == 404) {
        // Blame the metadata for listing an invalid file.
        throw GistLoaderException(
            GistLoaderFailureType.invalidExerciseMetadata);
      } else if (metadataResponse.statusCode == 403) {
        throw GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
      } else if (metadataResponse.statusCode != 200) {
        throw GistLoaderException(GistLoaderFailureType.unknown);
      }

      return extractGitHubResponseBody(contentResponse.body);
    });

    // This will rethrow the first exception created above, if one is thrown.
    final responses = await Future.wait(requests, eagerError: true);

    // Responses should be in the order they're listed in the metadata.
    final gistFiles = <GistFile>[
      for (var i = 0; i < metadata.files.length; i++)
        GistFile(
          name: metadata.files[i].name,
          content: responses[i],
        )
    ];

    final gist = Gist(
      files: gistFiles,
      description: metadata.name,
    );

    afterLoadHook?.call(gist);

    return gist;
  }
}

/// A representation of a Github gist.
class Gist {
  final String? id;
  final String? description;
  final String? htmlUrl;
  final String? summary;

  final bool public;

  final List<GistFile> files;

  Gist(
      {this.id,
      this.description,
      this.htmlUrl,
      this.summary,
      bool? public,
      List<GistFile>? files})
      : public = public ?? true,
        files = files ?? [];

  Gist.fromMap(Map<String, dynamic> map)
      : this(
            id: map['id'] as String?,
            description: map['description'] as String?,
            public: map['public'] as bool?,
            htmlUrl: map['html_url'] as String?,
            summary: map['summary'] as String?,
            files: (map['files'] as Map<String, dynamic>?)
                ?.entries
                .map((e) => GistFile.fromMap(e.key, e.value))
                .toList());

  dynamic operator [](String? key) {
    if (key == 'id') return id;
    if (key == 'description') return description;
    if (key == 'html_url') return htmlUrl;
    if (key == 'public') return public;
    if (key == 'summary') return summary;
    for (final file in files) {
      if (file.name == key) return file.content;
    }
    return null;
  }

  GistFile? getFile(String name, {bool ignoreCase = false}) {
    if (ignoreCase) {
      name = name.toLowerCase();
      return files.firstWhereOrNull((f) => f.name.toLowerCase() == name);
    } else {
      return files.firstWhereOrNull((f) => f.name == name);
    }
  }

  bool hasDartContent() {
    return files.any((GistFile file) {
      final name = file.name;
      final isDartFile = name.endsWith('.dart');
      return isDartFile && file.hasContent;
    });
  }

  bool hasWebContent() {
    return files.any((GistFile file) {
      final name = file.name;
      final isWebFile = name.endsWith('.html') || name.endsWith('.css');
      return isWebFile && file.hasContent;
    });
  }

  bool hasFlutterContent() {
    return files.any((GistFile file) {
      return detect_flutter.hasFlutterContent(file.content!);
    });
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      if (description != null) 'description': description,
      'public': public,
      if (summary != null) 'summary': summary,
      'files': {
        for (final file in files)
          if (file.hasContent)
            file.name: {
              if (file.content != null) 'content': file.content,
              if (file.rawUrl != null) 'raw_url': file.rawUrl,
              if (file.language != null) 'language': file.language,
              if (file.size != null) 'size': file.size
            }
      }
    };
  }

  String toJson() => json.encode(toMap());

  Gist clone() => Gist.fromMap(json.decode(toJson()) as Map<String, dynamic>);

  Gist cloneWithNewId(String newGistId) {
    final Map<String, dynamic> map = toMap();
    map['id'] = newGistId;
    return Gist.fromMap(map);
  }

  @override
  String toString() => id ?? '';
}

class GistFile {
  String name;
  String? content;
  String? rawUrl;
  String? language;
  int? size;

  GistFile({required this.name, this.content});

  GistFile.fromMap(this.name, data) {
    content = data['content'] as String?;
    rawUrl = data['raw_url'] as String?;
    language = data['language'] as String?;
    size = data['size'] as int?;
  }

  bool get hasContent {
    if (content != null) {
      return content?.trim().isNotEmpty ?? false;
    } else if (rawUrl != null && size != null) {
      return rawUrl!.isNotEmpty && size! > 0;
    }
    return false;
  }

  @override
  String toString() => '[$name, ${content?.length ?? 0} chars]';
}

abstract class GistController {
  Future<void> createNewGist();
}

class GistSummary {
  final String summaryText;
  final String linkText;

  const GistSummary(this.summaryText, this.linkText);
}

String _createReadmeContents(
    {String? title, String? summary, String? withLink}) {
  final buffer = StringBuffer('# $title\n');

  if (summary != null) {
    buffer.write('\n$summary\n');
  }

  if (withLink != null) {
    buffer.write('\nCreated with <3 with $withLink.\n');
  }

  return buffer.toString();
}
