// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:async';
import 'dart:convert' show json;
import 'dart:convert';

import 'package:dart_pad/sharing/exercise_metadata.dart';
import 'package:dart_pad/src/sample.dart' as sample;
import 'package:haikunator/haikunator.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart' as yaml;
import '../util/detect_flutter.dart' as detect_flutter;

final String _dartpadLink =
    '[dartpad.dartlang.org](https://dartpad.dartlang.org)';

final RegExp _gistRegex = RegExp(r'^[0-9a-f]+$');

enum FlutterSdkChannel {
  master,
  dev,
  beta,
  stable,
}

/// Return whether the given string is a valid github gist ID.
bool isLegalGistId(String id) {
  if (id == null) return false;
  // 4/8/2016: Github gist ids changed from 20 to 32 characters long.
  return _gistRegex.hasMatch(id) && id.length >= 5 && id.length <= 40;
}

/// Given either partial html text, or a full html document, extract out the
/// `<body>` tag.
String extractHtmlBody(String html) {
  if (html == null || !html.contains('<html')) {
    return html;
  } else {
    var body = r'body(?:\s[^>]*)?'; // Body tag with its attributes
    var any = r'[\s\S]'; // Any character including new line
    var bodyRegExp = RegExp('<$body>($any*)</$body>(?:(?!</$body>)$any)*',
        multiLine: true, caseSensitive: false);
    var match = bodyRegExp.firstMatch(html);
    return match == null ? '' : match.group(1).trim();
  }
}

Gist createSampleDartGist() {
  var gist = Gist();
  // "wispy-dust-1337", "patient-king-8872", "purple-breeze-9817"
  gist.description = Haikunator.haikunate();
  gist.files.add(GistFile(name: 'main.dart', content: sample.dartCode));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
  return gist;
}

Gist createSampleHtmlGist() {
  var gist = Gist();
  gist.description = Haikunator.haikunate();
  gist.files.add(GistFile(name: 'main.dart', content: sample.dartCodeHtml));
  gist.files.add(GistFile(name: 'index.html', content: sample.htmlCode));
  gist.files.add(GistFile(name: 'styles.css', content: sample.cssCode));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
  return gist;
}

Gist createSampleFlutterGist() {
  var gist = Gist();
  gist.description = Haikunator.haikunate();
  gist.files.add(GistFile(name: 'main.dart', content: sample.flutterCode));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
  return gist;
}

/// Find the best match for the given file names in the gist file info; return
/// the file (or `null` if no match is found).
GistFile chooseGistFile(Gist gist, List<String> names, [Function matcher]) {
  var files = gist.files;

  for (var name in names) {
    var file = files.firstWhere((f) => f.name == name, orElse: () => null);
    if (file != null) return file;
  }

  if (matcher != null) {
    return files.firstWhere((f) => matcher(f.name) as bool, orElse: () => null);
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
  final String message;
  final GistLoaderFailureType failureType;

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

  static final GistFilterHook _defaultLoadHook = (Gist gist) {
    // Update files based on our preferred file names.
    if (gist.getFile('body.html') != null &&
        gist.getFile('index.html') == null) {
      var file = gist.getFile('body.html');
      file.name = 'index.html';
    }

    if (gist.getFile('style.css') != null &&
        gist.getFile('styles.css') == null) {
      var file = gist.getFile('style.css');
      file.name = 'styles.css';
    }

    if (gist.getFile('main.dart') == null &&
        gist.files.where((f) => f.name.endsWith('.dart')).length == 1) {
      var file = gist.files.firstWhere((f) => f.name.endsWith('.dart'));
      file.name = 'main.dart';
    }

    // Extract the body out of the html file.
    var htmlFile = gist.getFile('index.html');
    if (htmlFile != null) {
      htmlFile.content = extractHtmlBody(htmlFile.content);
    }
  };

  static final GistFilterHook _defaultSaveHook = (Gist gist) {
    // Create a full html file on save.
    var hasStyles = gist.getFile('styles.css') != null;
    var styleRef =
        hasStyles ? '    <link rel="stylesheet" href="styles.css">\n' : '';

    var hasDart = gist.getFile('main.dart') != null;
    var dartRef = hasDart
        ? '    <script type="application/dart" src="main.dart"></script>\n'
        : '';

    var htmlFile = gist.getFile('index.html');
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
    var readmeFile = GistFile(
        name: 'readme.md',
        content: _createReadmeContents(
            title: gist.description,
            summary: gist.summary,
            withLink: _dartpadLink));
    gist.files.add(readmeFile);
  };

  final GistFilterHook afterLoadHook;
  final GistFilterHook beforeSaveHook;
  final http.Client _client;

  GistLoader({
    this.afterLoadHook,
    this.beforeSaveHook,
    http.Client client,
  }) : _client = client ?? http.Client();

  GistLoader.defaultFilters()
      : this(afterLoadHook: _defaultLoadHook, beforeSaveHook: _defaultSaveHook);

  /// Load the gist with the given id.
  Future<Gist> loadGist(String gistId) async {
    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    final response = await _client.get('$_gistApiUrl/$gistId');

    if (response.statusCode == 404) {
      throw const GistLoaderException(GistLoaderFailureType.contentNotFound);
    } else if (response.statusCode == 403) {
      throw const GistLoaderException(GistLoaderFailureType.rateLimitExceeded);
    } else if (response.statusCode != 200) {
      throw const GistLoaderException(GistLoaderFailureType.unknown);
    }

    final gist =
        Gist.fromMap(json.decode(response.body) as Map<String, dynamic>);

    if (afterLoadHook != null) {
      afterLoadHook(gist);
    }

    return gist;
  }

  Future<Gist> loadGistFromAPIDocs(
      String sampleId, FlutterSdkChannel channel) async {
    if (channel == FlutterSdkChannel.beta || channel == FlutterSdkChannel.dev) {
      throw ArgumentError('Only stable and master channels are supported!');
    }

    final sampleUrl = (channel == FlutterSdkChannel.master)
        ? '$_masterApiDocsUrl/$sampleId.dart'
        : '$_stableApiDocsUrl/$sampleId.dart';

    final response = await _client.get(sampleUrl);

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

    if (afterLoadHook != null) {
      afterLoadHook(gist);
    }

    return gist;
  }

  String _extractContents(String githubResponse) {
    // GitHub's API returns file contents as the "contents" field in a JSON
    // object. The field's value is in base64 encoding, but with line ending
    // characters ('\n') included.
    final contentJson = json.decode(githubResponse);
    final encodedContentStr =
        contentJson['content'].toString().replaceAll('\n', '');
    return utf8.decode(base64.decode(encodedContentStr));
  }

  Uri _buildContentsUrl(String owner, String repo, String path, [String ref]) {
    return Uri.https(
      _repoContentsAuthority,
      'repos/$owner/$repo/contents/$path',
      (ref != null && ref.isNotEmpty) ? {'ref': '$ref'} : null,
    );
  }

  Future<Gist> loadGistFromRepo({
    String owner,
    String repo,
    String path,
    String ref,
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

    final metadataContent = _extractContents(metadataResponse.body);

    ExerciseMetadata metadata;

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

      return _extractContents(contentResponse.body);
    });

    // This will rethrow the first exception created above, if one is thrown.
    final responses = await Future.wait(requests, eagerError: true);

    final gistFiles = <GistFile>[];

    // Responses should be in the order they're listed in the metadata.
    for (var i = 0; i < metadata.files.length; i++) {
      gistFiles.add(GistFile(
        name: metadata.files[i].name,
        content: responses[i],
      ));
    }

    final gist = Gist(
      files: gistFiles,
      description: metadata.name,
    );

    if (afterLoadHook != null) {
      afterLoadHook(gist);
    }

    return gist;
  }
}

/// A representation of a Github gist.
class Gist {
  String id;
  String description;
  String htmlUrl;
  String summary;

  bool public;

  List<GistFile> files;

  Gist({this.id, this.description, this.public = true, this.files}) {
    files ??= [];
  }

  Gist.fromMap(Map<String, dynamic> map) {
    id = map['id'] as String;
    description = map['description'] as String;
    public = map['public'] as bool;
    htmlUrl = map['html_url'] as String;
    summary = map['summary'] as String;
    var f = map['files'];
    files = List<GistFile>.from(f.keys
        .map((key) => GistFile.fromMap(key as String, f[key])) as Iterable);
  }

  dynamic operator [](String key) {
    if (key == 'id') return id;
    if (key == 'description') return description;
    if (key == 'html_url') return htmlUrl;
    if (key == 'public') return public;
    if (key == 'summary') return summary;
    for (var file in files) {
      if (file.name == key) return file.content;
    }
    return null;
  }

  GistFile getFile(String name, {bool ignoreCase = false}) {
    if (ignoreCase) {
      name = name.toLowerCase();
      return files.firstWhere((f) => f.name.toLowerCase() == name,
          orElse: () => null);
    } else {
      return files.firstWhere((f) => f.name == name, orElse: () => null);
    }
  }

  bool hasWebContent() {
    return files.any((GistFile file) {
      final isWebFile =
          file.name.endsWith('.html') || file.name.endsWith('.css');
      return isWebFile && file.content.trim().isNotEmpty;
    });
  }

  bool hasFlutterContent() {
    return files.any((GistFile file) {
      return detect_flutter.hasFlutterContent(file.content);
    });
  }

  Map toMap() {
    var m = <String, dynamic>{};
    if (id != null) m['id'] = id;
    if (description != null) m['description'] = description;
    if (public != null) m['public'] = public;
    if (summary != null) m['summary'] = summary;
    m['files'] = {};
    for (var file in files) {
      if (file.hasContent) {
        m['files'][file.name] = {'content': file.content};
      }
    }
    return m;
  }

  String toJson() => json.encode(toMap());

  Gist clone() => Gist.fromMap(json.decode(toJson()) as Map<String, dynamic>);

  @override
  String toString() => id;
}

class GistFile {
  String name;
  String content;

  GistFile({this.name, this.content});

  GistFile.fromMap(this.name, data) {
    content = data['content'] as String;
  }

  bool get hasContent => content != null && content.trim().isNotEmpty;

  @override
  String toString() => '[$name, ${content.length} chars]';
}

abstract class GistController {
  Future createNewGist();
}

class GistSummary {
  final String summaryText;
  final String linkText;

  GistSummary(this.summaryText, this.linkText);
}

String _createReadmeContents({String title, String summary, String withLink}) {
  var str = '# $title\n';

  if (summary != null) {
    str += '\n$summary\n';
  }

  if (withLink != null) {
    str += '\nCreated with <3 with $withLink.\n';
  }

  return str;
}
