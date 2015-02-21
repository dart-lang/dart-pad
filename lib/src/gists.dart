// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library gists;

import 'dart:async';
import 'dart:convert' show JSON;
import 'dart:html';

bool isLegalGistId(String id) {
  final RegExp regex = new RegExp(r'^[0-9a-f]+$');
  return regex.hasMatch(id) && id.length >= 5 && id.length <= 22;
}

String extractHtmlBody(String html) => (new HtmlHtmlElement()..setInnerHtml(html)).innerHtml.trim();

/**
 * A representation of a Github gist.
 */
class Gist {
  static final String _apiUrl = 'https://api.github.com/gists';

  static Future<Gist> loadGist(String gistId) {
    // Load the gist using the github gist API:
    // https://developer.github.com/v3/gists/#get-a-single-gist.
    return HttpRequest.getString('${_apiUrl}/${gistId}').then((data) {
      return new Gist(JSON.decode(data));
    });
  }

  Map _map;
  List<GistFile> _files;

  Gist(this._map) {
    Map f = _map['files'];
    _files = f.keys.map((key) => new GistFile._(key, f[key])).toList();
  }

  String get description => _map['description'];

  String get id => _map['id'];

  String get htmlUrl => _map['html_url'];

  bool get isPublic => _map['public'] == true;

  List<GistFile> getFiles() => _files;
}

class GistFile {
  final String name;
  final Map _data;

  GistFile._(this.name, this._data);

  int get size => _data['size'];
  String get rawUrl => _data['raw_url'];
  String get type => _data['type'];
  String get language => _data['language'];
  bool get isTruncated => _data['truncated'];
  String get contents => _data['content'];
}

/**
 * Find the best match for the given file names in the gist file info; return
 * the file (or `null` if no match is found).
 */
GistFile chooseGistFile(Gist gist, List<String> names, [Function matcher]) {
  List<GistFile> files = gist.getFiles();

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

