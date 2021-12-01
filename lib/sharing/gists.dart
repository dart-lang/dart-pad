// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:convert' show json;
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
  final gist = Gist(description: phrases.generate());
  gist.files.add(GistFile(name: 'main.dart', content: sample.dartCode));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
  return gist;
}

Gist createSampleHtmlGist() {
  final gist = Gist(description: phrases.generate());
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
  final gist = Gist(description: phrases.generate());
  gist.files.add(GistFile(name: 'main.dart', content: sample.flutterCode));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
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
  final String? message;
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
        gist.files.where((f) => f.name?.endsWith('.dart') ?? false).length ==
            1) {
      final file =
          gist.files.firstWhere((f) => f.name?.endsWith('.dart') ?? false);
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

    if (afterLoadHook != null) {
      afterLoadHook!(gist);
    }

    return gist;
  }
}

/// A representation of a Github gist.
class Gist {
  final String? id;
  final String? description;
  final String? htmlUrl;
  final String? summary;

  final bool? public;

  late final List<GistFile> files;

  Gist(
      {this.id,
      this.description,
      this.public = true,
      this.htmlUrl,
      this.summary,
      List<GistFile>? files}) {
    this.files = files ?? [];
  }

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
      return files.firstWhereOrNull((f) => f.name?.toLowerCase() == name);
    } else {
      return files.firstWhereOrNull((f) => f.name == name);
    }
  }

  bool hasWebContent() {
    return files.any((GistFile file) {
      final isWebFile =
          file.name!.endsWith('.html') || file.name!.endsWith('.css');
      return isWebFile && file.content!.trim().isNotEmpty;
    });
  }

  bool hasFlutterContent() {
    return files.any((GistFile file) {
      return detect_flutter.hasFlutterContent(file.content!);
    });
  }

  Map<String, dynamic> toMap() {
    final m = <String, dynamic>{};
    if (id != null) m['id'] = id;
    if (description != null) m['description'] = description;
    if (public != null) m['public'] = public;
    if (summary != null) m['summary'] = summary;
    m['files'] = {};
    for (final file in files) {
      if (file.hasContent) {
        m['files'][file.name] = {'content': file.content};
      }
    }
    return m;
  }

  String toJson() => json.encode(toMap());

  Gist clone() => Gist.fromMap(json.decode(toJson()) as Map<String, dynamic>);

  @override
  String toString() => id ?? '';
}

class GistFile {
  String? name;
  String? content;

  GistFile({this.name, this.content});

  GistFile.fromMap(this.name, data) {
    content = data['content'] as String?;
  }

  bool get hasContent => content?.trim().isNotEmpty ?? false;

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
