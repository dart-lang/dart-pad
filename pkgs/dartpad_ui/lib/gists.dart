// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:http/http.dart' as http;

class GistLoader {
  final http.Client client = http.Client();

  Future<Gist> load(String gistId) async {
    final response =
        await client.get(Uri.parse('https://api.github.com/gists/$gistId'));

    if (response.statusCode != 200) {
      throw Exception('Unable to load gist '
          '(${response.statusCode} ${response.reasonPhrase}})');
    }

    return Gist.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  void dispose() {
    client.close();
  }
}

class Gist {
  static const String defaultFileName = 'main.dart';

  final String id;
  final String? description;
  final String? owner;
  final List<GistFile> files;
  final List<String> validationIssues = [];

  Gist({
    required this.id,
    required this.description,
    required this.owner,
    required this.files,
  }) {
    _validateGist();
  }

  factory Gist.fromJson(Map<String, dynamic> json) {
/* {
  "id": "d3bd83918d21b6d5f778bdc69c3d36d6",
  "description": "Fibonacci",
  "owner": {
    "login": "flutterdevrelgists",
  },
  "public": false,
  "created_at": "2021-08-23T23:27:20Z",
  "updated_at": "2023-05-30T10:59:27Z",
  "comments": 0,
  "user": null,
  "truncated": false,
  "files": {
    "main.dart": {
      "filename": "main.dart",
      "type": "application/vnd.dart",
      "language": "Dart",
      "raw_url": "https://gist.githubusercontent.com/flutterdevrelgists/d3bd83918d21b6d5f778bdc69c3d36d6/raw/5eaecf3519fe453298d077068194720c9729be62/main.dart",
      "size": 369,
      "truncated": false,
      "content": "..."
    }
  },
} */
    final owner = json['owner'] as Map<String, dynamic>;
    final files = json['files'] as Map<String, dynamic>;

    return Gist(
      id: json['id'] as String,
      description: json['description'] as String?,
      owner: owner['login'] as String?,
      files: files.values
          .cast<Map<String, dynamic>>()
          .map(GistFile.fromJson)
          .toList(),
    );
  }

  String? get mainDartSource {
    GistFile? file;

    // First, try and load 'main.dart'.
    file = files.firstWhereOrNull((file) => file.fileName == defaultFileName);

    // Fall back on the older (unintentional) contention - loading from the
    // single dart file in a gist.
    file ??= files.singleWhereOrNull((file) => file.fileName.endsWith('.dart'));

    return file?.content;
  }

  void _validateGist() {
    final file =
        files.singleWhereOrNull((file) => file.fileName.endsWith('.dart'));

    if (file == null) {
      validationIssues.add('Warning: no Dart file found in the gist');
    } else if (file.fileName != defaultFileName) {
      validationIssues.add('Warning: no gist content in $defaultFileName '
          '(loading from ${file.fileName})');
    }
  }
}

class GistFile {
  final String fileName;
  final bool truncated;
  final String rawUrl;
  final String content;

  GistFile({
    required this.fileName,
    required this.truncated,
    required this.rawUrl,
    required this.content,
  });

  factory GistFile.fromJson(Map<String, dynamic> json) {
    return GistFile(
      fileName: json['filename'] as String,
      truncated: json['truncated'] as bool,
      rawUrl: json['raw_url'] as String,
      content: json['content'] as String,
    );
  }
}
