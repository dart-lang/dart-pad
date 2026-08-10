// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/startup/gist_loader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GistLoader', () {
    const gistId = 'aa5a315d61ae9438b18d';
    const gistUrl = 'https://api.github.com/gists/$gistId';

    String gistResponse(
      Map<String, Map<String, Object?>> files, {
      bool truncated = false,
    }) {
      return jsonEncode({'truncated': truncated, 'files': files});
    }

    test('moves flat Dart files into lib and finds a project root and entrypoint', () async {
      final api = MemoryWorkspaceResourceApi();
      const loader = GistLoader(gistId: gistId);
      final response = gistResponse({
        'pubspec.yaml': {'filename': 'pubspec.yaml', 'content': 'name: gist_project'},
        'main.dart': {'filename': 'main.dart', 'content': "import 'helper.dart'; void main() {}"},
        'helper.dart': {'filename': 'helper.dart', 'content': 'class Helper {}'},
        'README.md': {'filename': 'README.md', 'content': '# Gist'},
      });

      await http.runWithClient(
        () async {
          final result = await loader.loadGist(api.root);
          expect(result.projectDir, '');
          expect(result.entryPath, 'lib/main.dart');
          expect(result.packageRoot, '');
        },
        () => MockClient((request) async {
          expect(request.url.toString(), gistUrl);
          expect(request.headers['accept'], 'application/vnd.github+json');
          return http.Response(response, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec.yaml'), 'name: gist_project');
      expect(await api.readFileAsText('lib/main.dart'), "import 'helper.dart'; void main() {}");
      expect(await api.readFileAsText('lib/helper.dart'), 'class Helper {}');
      expect(await api.fileExist('main.dart'), isFalse);
      expect(await api.fileExist('helper.dart'), isFalse);
      expect(await api.readFileAsText('README.md'), '# Gist');
    });

    test('uses the configured entrypoint fallbacks', () async {
      final testCases = <({Map<String, String> files, String? entryPath})>[
        (
          files: {'main.dart': 'void main() {}'},
          entryPath: 'lib/main.dart',
        ),
        (files: {'lib/main.dart': 'void main() {}'}, entryPath: 'lib/main.dart'),
        (files: {'example.dart': 'void main() {}'}, entryPath: 'lib/example.dart'),
        (files: {'README.md': '# Read me'}, entryPath: 'README.md'),
        (files: {'notes.txt': 'No entrypoint'}, entryPath: null),
      ];

      for (final testCase in testCases) {
        final files = testCase.files.map(
          (name, content) => MapEntry(
            name,
            <String, Object?>{'filename': name, 'content': content},
          ),
        );
        final api = MemoryWorkspaceResourceApi();

        await http.runWithClient(
          () async {
            final result = await const GistLoader(gistId: gistId).loadGist(api.root);
            expect(result.entryPath, testCase.entryPath);
            expect(result.projectDir, '');
            expect(result.packageRoot, isNull);
          },
          () => MockClient((request) async => http.Response(gistResponse(files), 200)),
        );
      }
    });

    test('finds the nearest pubspec directory of the selected entrypoint', () async {
      final api = MemoryWorkspaceResourceApi();
      final response = gistResponse({
        'packages/demo/pubspec.yaml': {'filename': 'packages/demo/pubspec.yaml', 'content': 'name: demo'},
        'packages/demo/lib/main.dart': {
          'filename': 'packages/demo/lib/main.dart',
          'content': 'void main() {}',
        },
      });

      await http.runWithClient(
        () async {
          final result = await const GistLoader(gistId: gistId).loadGist(api.root);
          expect(result.projectDir, 'packages/demo');
          expect(result.entryPath, 'packages/demo/lib/main.dart');
          expect(result.packageRoot, 'packages/demo');
        },
        () => MockClient((request) async => http.Response(response, 200)),
      );
    });

    test('loads a truncated file from its raw URL', () async {
      final api = MemoryWorkspaceResourceApi();
      const rawUrl = 'https://gist.githubusercontent.com/example/raw/main.dart';
      final response = gistResponse({
        'main.dart': {
          'filename': 'main.dart',
          'truncated': true,
          'raw_url': rawUrl,
        },
      });
      final rawBytes = Uint8List.fromList([0, 255, 42]);

      await http.runWithClient(
        () async {
          final result = await const GistLoader(gistId: gistId).loadGist(api.root);
          expect(result.entryPath, 'lib/main.dart');
        },
        () => MockClient((request) async {
          if (request.url.toString() == gistUrl) {
            return http.Response(response, 200);
          }
          expect(request.url.toString(), rawUrl);
          return http.Response.bytes(rawBytes, 200);
        }),
      );

      expect(await api.readFileAsBytes('lib/main.dart'), rawBytes);
    });

    test('reports a failed raw URL response', () async {
      final api = MemoryWorkspaceResourceApi();
      const rawUrl = 'https://gist.githubusercontent.com/example/raw/main.dart';
      final response = gistResponse({
        'main.dart': {
          'filename': 'main.dart',
          'truncated': true,
          'raw_url': rawUrl,
        },
      });

      await http.runWithClient(
        () async {
          await expectLater(
            const GistLoader(gistId: gistId).loadGist(api.root),
            throwsException,
          );
        },
        () => MockClient((request) async {
          if (request.url.toString() == gistUrl) {
            return http.Response(response, 200);
          }
          expect(request.url.toString(), rawUrl);
          return http.Response('Not Found', 404);
        }),
      );
    });

    test('rejects an unsafe file path before writing any files', () async {
      final api = MemoryWorkspaceResourceApi();
      final response = gistResponse({
        'valid.dart': {'filename': 'valid.dart', 'content': 'void main() {}'},
        '../outside.dart': {'filename': '../outside.dart', 'content': 'unsafe'},
      });

      await http.runWithClient(
        () async {
          await expectLater(
            const GistLoader(gistId: gistId).loadGist(api.root),
            throwsArgumentError,
          );
        },
        () => MockClient((request) async => http.Response(response, 200)),
      );

      expect(await api.fileExist('valid.dart'), isFalse);
    });

    test('rejects a truncated file list', () async {
      final api = MemoryWorkspaceResourceApi();
      await http.runWithClient(
        () async {
          await expectLater(
            const GistLoader(gistId: gistId).loadGist(api.root),
            throwsFormatException,
          );
        },
        () => MockClient(
          (request) async => http.Response(gistResponse({}, truncated: true), 200),
        ),
      );
    });

    test('reports failed and malformed gist responses', () async {
      final api = MemoryWorkspaceResourceApi();
      await http.runWithClient(
        () async {
          await expectLater(
            const GistLoader(gistId: gistId).loadGist(api.root),
            throwsException,
          );
        },
        () => MockClient((request) async => http.Response('Not Found', 404)),
      );

      await http.runWithClient(
        () async {
          await expectLater(
            const GistLoader(gistId: gistId).loadGist(api.root),
            throwsFormatException,
          );
        },
        () => MockClient((request) async => http.Response('not json', 200)),
      );
    });
  });
}
