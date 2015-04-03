// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

import 'package:dart_pad/src/sample.dart' as sample;

// TODO: Save gists as valid pub packages (pubspecs, and readmes).

/**
 * Return whether the given string is a valid github gist ID.
 */
bool isLegalGistId(String id) {
  final RegExp regex = new RegExp(r'^[0-9a-f]+$');
  return regex.hasMatch(id) && id.length >= 5 && id.length <= 22;
}

/**
 * Given either partial html text, or a full html document, extract out the
 * `<body>` tag.
 */
String extractHtmlBody(String html) {
  if (!html.contains('<html')) {
    return html;
  } else {
    var body = r'body(?:\s[^>]*)?'; // Body tag with its attributes
    var any = r'[\s\S]'; // Any character including new line
    var bodyRegExp = new RegExp("<$body>($any*)</$body>(?:(?!</$body>)$any)*",
        multiLine: true, caseSensitive: false);
    var match = bodyRegExp.firstMatch(html);
    return match == null ? '' : match.group(1).trim();
  }
}

Gist createSampleGist() {
  Gist gist = new Gist();
  gist.description = 'Untitled';
  gist.files.add(new GistFile(name: 'main.dart', content: sample.dartCode));
  gist.files.add(new GistFile(name: 'index.html', content: '\n'));
  gist.files.add(new GistFile(name: 'styles.css', content: '\n'));
  return gist;
}

/**
 * Find the best match for the given file names in the gist file info; return
 * the file (or `null` if no match is found).
 */
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

/// A representation of a Github gist.
class Gist {
  static final String _apiUrl = 'https://api.github.com/gists';

  /// Load the gist with the given id.
  static Future<Gist> loadGist(String gistId) {
    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return HttpRequest.getString('${_apiUrl}/${gistId}').then((data) {
      return new Gist.fromMap(JSON.decode(data))..reconcile();
    });
  }

  /// Create a new gist and return the newly created Gist.
  static Future<Gist> createAnon(Gist gist) {
    // POST /gists
    return HttpRequest.request(_apiUrl, method: 'POST',
        sendData: gist.toJson()).then((HttpRequest request) {
      return new Gist.fromMap(JSON.decode(request.responseText));
    });
  }

  String id;
  String description;
  String html_url;

  bool public;

  List<GistFile> files;

  Gist({this.id, this.description, this.public: true, this.files}) {
    if (files == null) files = [];
  }

  Gist.fromMap(Map map) {
    id = map['id'];
    description = map['description'];
    public = map['public'];
    html_url = map['html_url'];

    Map f = map['files'];
    files = f.keys.map((key) => new GistFile.fromMap(key, f[key])).toList();
  }

  dynamic operator[](String key) {
    if (key == 'id') return id;
    if (key == 'description') return description;
    if (key == 'html_url') return html_url;
    if (key == 'public') return public;
    for (GistFile file in files) {
      if (file.name == key) return file.content;
    }
    return null;
  }

  /// Update files based on our preferred file names.
  void reconcile() {
    if (getFile('body.html') != null && getFile('index.html') == null) {
      GistFile file = getFile('body.html');
      file.name = 'index.html';
    }

    if (getFile('style.css') != null && getFile('styles.css') == null) {
      GistFile file = getFile('style.css');
      file.name = 'styles.css';
    }

    if (getFile('main.dart') == null &&
        files.where((f) => f.name.endsWith('.dart')).length == 1) {
      GistFile file = files.firstWhere((f) => f.name.endsWith('.dart'));
      file.name = 'main.dart';
    }
  }

  GistFile getFile(String name) =>
      files.firstWhere((f) => f.name == name, orElse: () => null);

  Map toMap() {
    Map m = {};
    if (id != null) m['id'] = id;
    if (description != null) m['description'] = description;
    if (public != null) m['public'] = public;
    m['files'] = {};
    for (GistFile file in files) {
      if (file.hasContent) {
        m['files'][file.name] = {
          'content': file.content
        };
      }
    }
    return m;
  }

  String toJson() => JSON.encode(toMap());

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

  String toString() => '[${name}, ${content.length} chars]';
}
