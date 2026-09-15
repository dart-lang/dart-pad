// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_frontend/features/startup/archive_loader.dart';
import 'package:dartpad_frontend/features/startup/gist_loader.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source_loader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'initial_project_state_test.dart' show sdks;

void main() {
  for (final version in [null, '1.2.3', '1.2.3+build.2']) {
    test('loads ${version ?? 'latest'} package version via metadata archive_url', () async {
      final requests = <Uri>[];
      await http.runWithClient(
        () async {
          final loader = await ArchiveLoader.forPackage('demo', version: version);
          expect(loader.archiveUrl, 'https://pub.dev/api/archives/demo-1.2.3.tar.gz');
        },
        () => MockClient((request) async {
          requests.add(request.url);
          final metadata = {'archive_url': 'https://pub.dev/api/archives/demo-1.2.3.tar.gz'};
          return http.Response(jsonEncode(version == null ? {'latest': metadata} : metadata), 200);
        }),
      );
      expect(requests.single.path, version == null ? '/api/packages/demo' : '/api/packages/demo/versions/$version');
    });
  }
  test('reports missing package versions without loading latest', () async {
    await http.runWithClient(() async {
      await expectLater(ArchiveLoader.forPackage('demo', version: '0.0.0'), throwsFormatException);
    }, () => MockClient((_) async => http.Response('Not found', 404)));
  });
  test('maps all flat Gist Dart files and rejects relocation collisions', () async {
    Future<void> check(Map<String, String> files, {bool collision = false}) async {
      await http.runWithClient(
        () async {
          final future = const GistLoader(gistId: 'abc').loadGist();
          if (collision) {
            await expectLater(future, throwsArgumentError);
          } else {
            final project = await future;
            expect(project.pathMapping, {
              'main.dart': 'lib/main.dart',
              'helper.dart': 'lib/helper.dart',
              'README.md': 'README.md',
            });
            final state = InitialProjectState.resolve(
              ProjectRequest.fromUri(Uri.parse('?gist=abc&file=main.dart&file=README.md&entrypoint=main.dart')),
              project,
              sdks,
            );
            expect(state.files, ['lib/main.dart', 'README.md']);
            expect(state.entrypoint, 'lib/main.dart');
            expect(state.root, '');
          }
        },
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({
              'files': {
                for (final entry in files.entries) entry.key: {'filename': entry.key, 'content': entry.value},
              },
            }),
            200,
          ),
        ),
      );
    }

    await check({'main.dart': 'void main() {}', 'helper.dart': 'class Helper {}', 'README.md': '# Gist'});
    await check({'main.dart': 'void main() {}', 'lib/main.dart': 'void main() {}'}, collision: true);
  });
  test('sample uses the common README and SDK resolver', () async {
    final archive = Archive();
    for (final entry in {
      'README.md': '# Counter',
      'pubspec.yaml': 'flutter: {}',
      'lib/main.dart': 'void main() {}',
    }.entries) {
      final bytes = utf8.encode(entry.value);
      archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
    }
    final encoded = Uint8List.fromList(TarEncoder().encode(archive));
    await http.runWithClient(
      () async {
        final request = ProjectRequest.example('counter');
        final state = InitialProjectState.resolve(request, await loadProjectSource(request.source), sdks);
        expect(state.files, ['README.md']);
        expect(state.entrypoint, 'lib/main.dart');
        expect(state.sdk, sdks.last);
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/examples/counter.tar.gz'));
        return http.Response.bytes(encoded, 200);
      }),
    );
  });
}
