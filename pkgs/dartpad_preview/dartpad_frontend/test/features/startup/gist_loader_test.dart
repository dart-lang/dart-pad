// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('GistProjectSource', () {
    const gistId = 'aa5a315d61ae9438b18d';
    const gistUrl = 'https://api.github.com/gists/$gistId';

    String gistResponse(
      Map<String, Map<String, Object?>> files, {
      bool truncated = false,
    }) {
      return jsonEncode({'truncated': truncated, 'files': files});
    }

    test('moves flat Dart files into lib and preserves other files', () async {
      final api = MemoryWorkspaceResourceApi();
      const source = GistProjectSource(gistId);
      final response = gistResponse({
        'pubspec.yaml': {'filename': 'pubspec.yaml', 'content': 'name: gist_project'},
        'main.dart': {'filename': 'main.dart', 'content': "import 'helper.dart'; void main() {}"},
        'helper.dart': {'filename': 'helper.dart', 'content': 'class Helper {}'},
        'README.md': {'filename': 'README.md', 'content': '# Gist'},
      });

      await http.runWithClient(
        () async {
          await loadInto(source, api.root);
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

    test('preserves nested package files', () async {
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
          await loadInto(const GistProjectSource(gistId), api.root);
        },
        () => MockClient((request) async => http.Response(response, 200)),
      );
    });

    test('startup generates a missing pubspec after loading and selecting the SDK', () async {
      final api = MemoryWorkspaceResourceApi();
      final response = gistResponse({
        'main.dart': {
          'filename': 'main.dart',
          'content': "import 'package:flutter/material.dart';\nvoid main() {}",
        },
      });

      await http.runWithClient(
        () async {
          final request = ProjectRequest.fromUri(Uri.parse('?gist=$gistId'));
          final project = await request.source.loadProject();
          expect(project.containsFile('pubspec.yaml'), isFalse);
          final state = InitialProjectState.resolve(request, project, const [
            SdkInfo(id: 'dart', name: 'Dart', path: 'dart/', dartVersion: '3.13.3'),
            SdkInfo(
              id: 'flutter',
              name: 'Flutter',
              path: 'flutter/',
              dartVersion: '3.14.0 (build 3.14.0-201.0.dev)',
              flutterVersion: '3.48.0',
            ),
          ]);
          expect(state.sdk.isFlutter, isTrue);
          expect(state.hasPubspec, isTrue);
          await ProjectLoader.writeFiles(api.root, project);
        },
        () => MockClient((request) async => http.Response(response, 200)),
      );

      expect(await api.readFileAsText('pubspec.yaml'), contains('sdk: ^3.14.0-0'));
      expect(await api.readFileAsText('pubspec.yaml'), contains('sdk: flutter'));
      expect(await api.readFileAsText('pubspec.yaml'), contains('uses-material-design: true'));
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
          await loadInto(const GistProjectSource(gistId), api.root);
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
            loadInto(const GistProjectSource(gistId), api.root),
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
            loadInto(const GistProjectSource(gistId), api.root),
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
            loadInto(const GistProjectSource(gistId), api.root),
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
            loadInto(const GistProjectSource(gistId), api.root),
            throwsException,
          );
        },
        () => MockClient((request) async => http.Response('Not Found', 404)),
      );

      await http.runWithClient(
        () async {
          await expectLater(
            loadInto(const GistProjectSource(gistId), api.root),
            throwsFormatException,
          );
        },
        () => MockClient((request) async => http.Response('not json', 200)),
      );
    });
  });
}

Future<void> loadInto(GistProjectSource source, WorkspaceFolder root) async {
  await ProjectLoader.writeFiles(root, await source.loadProject());
}
