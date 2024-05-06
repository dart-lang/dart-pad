// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:dartpad_ui/gists.dart';
import 'package:test/test.dart';

void main() {
  group('gists', () {
    test('parses json', () {
      final gist =
          Gist.fromJson(jsonDecode(jsonSample) as Map<String, dynamic>);

      expect(gist.id, 'd3bd83918d21b6d5f778bdc69c3d36d6');
      expect(gist.description, 'Fibonacci');
      expect(gist.owner, 'flutterdevrelgists');
      expect(gist.files, isNotEmpty);
    });

    test('finds main.dart', () {
      final gist =
          Gist.fromJson(jsonDecode(jsonSample) as Map<String, dynamic>);

      expect(gist.mainDartSource, isNotNull);
    });

    test('recognizes main.dart missing', () {
      final gist =
          Gist.fromJson(jsonDecode(jsonSampleNoMain) as Map<String, dynamic>);

      expect(gist.mainDartSource, isNull);
    });

    test('validates main.dart missing', () {
      final gist =
          Gist.fromJson(jsonDecode(jsonSampleNoMain) as Map<String, dynamic>);

      expect(gist.validationIssues, isNotEmpty);
    });

    test('validates unexpected dart content file', () {
      final gist = Gist.fromJson(
          jsonDecode(jsonSampleAlternativeFile) as Map<String, dynamic>);

      expect(gist.validationIssues, isNotEmpty);
    });
  });
}

const String jsonSample = '''
{
  "id": "d3bd83918d21b6d5f778bdc69c3d36d6",
  "description": "Fibonacci",
  "owner": {
    "login": "flutterdevrelgists"
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
  }
}
''';

const String jsonSampleNoMain = '''
{
  "id": "d3bd83918d21b6d5f778bdc69c3d36d6",
  "description": "Fibonacci",
  "owner": {
    "login": "flutterdevrelgists"
  },
  "public": false,
  "created_at": "2021-08-23T23:27:20Z",
  "updated_at": "2023-05-30T10:59:27Z",
  "comments": 0,
  "user": null,
  "truncated": false,
  "files": {
    "main.html": {
      "filename": "main.html",
      "type": "application/vnd.dart",
      "language": "Dart",
      "raw_url": "https://gist.githubusercontent.com/flutterdevrelgists/d3bd83918d21b6d5f778bdc69c3d36d6/raw/5eaecf3519fe453298d077068194720c9729be62/main.dart",
      "size": 369,
      "truncated": false,
      "content": "..."
    }
  }
}
''';

const String jsonSampleAlternativeFile = '''
{
  "id": "d3bd83918d21b6d5f778bdc69c3d36d6",
  "description": "Fibonacci",
  "owner": {
    "login": "flutterdevrelgists"
  },
  "public": false,
  "created_at": "2021-08-23T23:27:20Z",
  "updated_at": "2023-05-30T10:59:27Z",
  "comments": 0,
  "user": null,
  "truncated": false,
  "files": {
    "sample_1.dart": {
      "filename": "sample_1.dart",
      "type": "application/vnd.dart",
      "language": "Dart",
      "raw_url": "https://gist.githubusercontent.com/flutterdevrelgists/d3bd83918d21b6d5f778bdc69c3d36d6/raw/5eaecf3519fe453298d077068194720c9729be62/main.dart",
      "size": 369,
      "truncated": false,
      "content": "..."
    }
  }
}
''';
