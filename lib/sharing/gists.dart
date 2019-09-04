// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:async';
import 'dart:convert' show json;
import 'dart:html';

import 'package:dart_pad/src/sample.dart' as sample;
import 'package:haikunator/haikunator.dart';

final String _dartpadLink =
    '[dartpad.dartlang.org](https://dartpad.dartlang.org)';

final RegExp _gistRegex = RegExp(r'^[0-9a-f]+$');

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

Gist createSampleGist() {
  Gist gist = Gist();
  // "wispy-dust-1337", "patient-king-8872", "purple-breeze-9817"
  gist.description = Haikunator.haikunate();
  gist.files.add(GistFile(name: 'main.dart', content: sample.dartCode));
  gist.files.add(GistFile(name: 'index.html', content: '\n'));
  gist.files.add(GistFile(name: 'styles.css', content: '\n'));
  gist.files.add(GistFile(
      name: 'readme.md',
      content: _createReadmeContents(
          title: gist.description, withLink: _dartpadLink)));
  return gist;
}

/// Find the best match for the given file names in the gist file info; return
/// the file (or `null` if no match is found).
GistFile chooseGistFile(Gist gist, List<String> names, [Function matcher]) {
  List<GistFile> files = gist.files;

  for (String name in names) {
    GistFile file = files.firstWhere((f) => f.name == name, orElse: () => null);
    if (file != null) return file;
  }

  if (matcher != null) {
    return files.firstWhere((f) => matcher(f.name), orElse: () => null);
  } else {
    return null;
  }
}

typedef void GistFilterHook(Gist gist);

enum GistLoaderFailureType {
  unknown,
  gistDoesNotExist,
  rateLimitExceeded,
}

class GistLoaderException {
  final GistLoaderFailureType failureType;

  const GistLoaderException(this.failureType);
}

/// A class to load and save gists. Gists can optionally be modified after
/// loading and before saving.
class GistLoader {
  static final String _githubApiUrl = 'https://api.github.com/gists';
  // TODO(redbrogdon): Remove 'master-' once the new docs go live.
  static final String _apiDocsUrl = 'https://master-api.flutter.dev/snippets';
  static final String _sampleMain = 'void main() => runApp(MyApp());';
  static final String _dartPadMain = '''
import 'package:flutter_web/material.dart';
import 'package:flutter_web_ui/ui.dart' as ui;

void main() async {
  await ui.webOnlyInitializePlatform();
  runApp(MyApp());
}''';

  static final GistFilterHook _defaultLoadHook = (Gist gist) {
    // Update files based on our preferred file names.
    if (gist.getFile('body.html') != null &&
        gist.getFile('index.html') == null) {
      GistFile file = gist.getFile('body.html');
      file.name = 'index.html';
    }

    if (gist.getFile('style.css') != null &&
        gist.getFile('styles.css') == null) {
      GistFile file = gist.getFile('style.css');
      file.name = 'styles.css';
    }

    if (gist.getFile('main.dart') == null &&
        gist.files.where((f) => f.name.endsWith('.dart')).length == 1) {
      GistFile file = gist.files.firstWhere((f) => f.name.endsWith('.dart'));
      file.name = 'main.dart';
    }

    // Extract the body out of the html file.
    GistFile htmlFile = gist.getFile('index.html');
    if (htmlFile != null) {
      htmlFile.content = extractHtmlBody(htmlFile.content);
    }
  };

  static final GistFilterHook _defaultSaveHook = (Gist gist) {
    // Create a full html file on save.
    bool hasStyles = gist.getFile('styles.css') != null;
    String styleRef =
        hasStyles ? '    <link rel="stylesheet" href="styles.css">\n' : '';

    bool hasDart = gist.getFile('main.dart') != null;
    String dartRef = hasDart
        ? '    <script type="application/dart" src="main.dart"></script>\n'
        : '';

    GistFile htmlFile = gist.getFile('index.html');
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
    GistFile readmeFile = GistFile(
        name: 'readme.md',
        content: _createReadmeContents(
            title: gist.description,
            summary: gist.summary,
            withLink: _dartpadLink));
    gist.files.add(readmeFile);
  };

  final GistFilterHook afterLoadHook;
  final GistFilterHook beforeSaveHook;

  GistLoader({this.afterLoadHook, this.beforeSaveHook});

  GistLoader.defaultFilters()
      : afterLoadHook = _defaultLoadHook,
        beforeSaveHook = _defaultSaveHook;

  /// Load the gist with the given id.
  Future<Gist> loadGist(String gistId) async {
    try {
      // Load the gist using the github gist API:
      // https://developer.github.com/v3/gists/#get-a-single-gist.
      final gistJson = await HttpRequest.getString('$_githubApiUrl/$gistId');
      final gist = Gist.fromMap(json.decode(gistJson));

      if (afterLoadHook != null) {
        afterLoadHook(gist);
      }

      return gist;
    } catch (ex) {
      if (ex.target.status == 404) {
        throw const GistLoaderException(GistLoaderFailureType.gistDoesNotExist);
      } else if (ex.target.status == 403) {
        throw const GistLoaderException(
            GistLoaderFailureType.rateLimitExceeded);
      } else {
        throw const GistLoaderException(GistLoaderFailureType.unknown);
      }
    }
  }

  Future<Gist> loadGistFromAPIDocs(String sampleId) async {
    final contents = await HttpRequest.getString('$_apiDocsUrl/$sampleId.dart');

    // TODO(redbrogdon) This should be removed once the online sample code for
    // IDEs (which is what api.flutter.dev/snippets makes available) can be
    // aligned with what DartPad needs.
    //
    // Remove everything up to and including main(), and replace it with a valid
    // set of flutter_web imports and a new main() that waits for platform
    // readiness.
    final spliceIndex = contents.indexOf(_sampleMain) + _sampleMain.length;
    final modifiedCode = '$_dartPadMain${contents.substring(spliceIndex)}';

    final mainFile = GistFile(
      name: 'main.dart',
      content: modifiedCode,
    );

    final gist = Gist(files: [mainFile]);

    if (afterLoadHook != null) {
      afterLoadHook(gist);
    }

    return Gist(files: [mainFile]);
  }

  /// Create a new gist and return the newly created Gist.
  Future<Gist> createAnon(Gist gist) {
    // POST /gists
    if (beforeSaveHook != null) {
      gist = gist.clone();
      beforeSaveHook(gist);
    }

    return HttpRequest.request(_githubApiUrl,
            method: 'POST', sendData: gist.toJson())
        .then((HttpRequest request) {
      Gist gist = Gist.fromMap(json.decode(request.responseText));
      if (afterLoadHook != null) {
        afterLoadHook(gist);
      }
      return gist;
    });
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

  Gist.fromMap(Map map) {
    id = map['id'];
    description = map['description'];
    public = map['public'];
    htmlUrl = map['html_url'];
    summary = map['summary'];
    Map f = map['files'];
    files = f.keys.map((key) => GistFile.fromMap(key, f[key])).toList();
  }

  dynamic operator [](String key) {
    if (key == 'id') return id;
    if (key == 'description') return description;
    if (key == 'html_url') return htmlUrl;
    if (key == 'public') return public;
    if (key == 'summary') return summary;
    for (GistFile file in files) {
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
      final bool isWebFile =
          file.name.endsWith('.html') || file.name.endsWith('.css');
      return isWebFile && file.content.trim().isNotEmpty;
    });
  }

  Map toMap() {
    Map m = {};
    if (id != null) m['id'] = id;
    if (description != null) m['description'] = description;
    if (public != null) m['public'] = public;
    if (summary != null) m['summary'] = summary;
    m['files'] = {};
    for (GistFile file in files) {
      if (file.hasContent) {
        m['files'][file.name] = {'content': file.content};
      }
    }
    return m;
  }

  String toJson() => json.encode(toMap());

  Gist clone() => Gist.fromMap(json.decode(toJson()));

  @override
  String toString() => id;
}

class GistFile {
  String name;
  String content;

  GistFile({this.name, this.content});

  GistFile.fromMap(this.name, Map data) {
    content = data['content'];
  }

  bool get hasContent => content != null && content.trim().isNotEmpty;

  @override
  String toString() => '[$name, ${content.length} chars]';
}

abstract class GistController {
  Future createNewGist();

  Future shareAnon({String summary});
}

/// A class to store gists in html's localStorage.
class GistStorage {
  static final String _key = 'gist';

  String _storedId;

  GistStorage() {
    Gist gist = getStoredGist();
    if (gist != null) {
      _storedId = gist.id;
    }
  }

  bool get hasStoredGist => window.localStorage.containsKey(_key);

  /// Return the id of the stored gist. This will return `null` if there is no
  /// gist stored.
  String get storedId =>
      _storedId == null || _storedId.isEmpty ? null : _storedId;

  Gist getStoredGist() {
    String data = window.localStorage[_key];
    return data == null ? null : Gist.fromMap(json.decode(data));
  }

  void setStoredGist(Gist gist) {
    _storedId = gist.id;
    window.localStorage[_key] = gist.toJson();
  }

  void clearStoredGist() {
    _storedId = null;
    window.localStorage.remove(_key);
  }
}

class GistSummary {
  final String summaryText;
  final String linkText;

  GistSummary(this.summaryText, this.linkText);
}

String _createReadmeContents({String title, String summary, String withLink}) {
  String str = '# $title\n';

  if (summary != null) {
    str += '\n$summary\n';
  }

  if (withLink != null) {
    str += '\nCreated with <3 with $withLink.\n';
  }

  return str;
}
