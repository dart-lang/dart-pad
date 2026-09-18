// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'initial_project_state_test.dart' show sdks;

void main() {
  for (final version in [null, '1.2.3', '1.2.3+build.2']) {
    test('loads ${version ?? 'latest'} package version via metadata archive_url', () async {
      final requests = <Uri>[];
      final archive = Uint8List.fromList(TarEncoder().encode(Archive()));
      await http.runWithClient(
        () async {
          final project = await PackageProjectSource('demo', version: version).loadProject();
          expect(project.paths, isEmpty);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          if (request.url.path == '/api/archives/demo-1.2.3.tar.gz') {
            return http.Response.bytes(archive, 200);
          }
          final metadata = {'archive_url': 'https://pub.dev/api/archives/demo-1.2.3.tar.gz'};
          return http.Response(jsonEncode(version == null ? {'latest': metadata} : metadata), 200);
        }),
      );
      expect(requests, [
        Uri.https('pub.dev', version == null ? '/api/packages/demo' : '/api/packages/demo/versions/$version'),
        Uri.https('pub.dev', '/api/archives/demo-1.2.3.tar.gz'),
      ]);
    });
  }
  test('reports missing package versions without loading latest', () async {
    await http.runWithClient(() async {
      await expectLater(
        const PackageProjectSource('demo', version: '0.0.0').loadProject(),
        throwsFormatException,
      );
    }, () => MockClient((_) async => http.Response('Not found', 404)));
  });
  group('FlutterApiDocsProjectSource', () {
    for (final (channel, host) in [
      (null, 'api.flutter.dev'),
      ('stable', 'api.flutter.dev'),
      ('beta', 'api.flutter.dev'),
      ('unknown', 'api.flutter.dev'),
      ('main', 'main-api.flutter.dev'),
      ('master', 'main-api.flutter.dev'),
    ]) {
      test('loads $channel from $host using the bundled Flutter SDK', () async {
        final query = '?sample_id=material.AppBar.1${channel == null ? '' : '&channel=$channel'}';
        final request = ProjectRequest.fromUri(Uri.parse(query));
        final source = request.source as FlutterApiDocsProjectSource;
        await http.runWithClient(
          () async {
            final project = await source.loadProject();
            expect(project.paths, ['lib/main.dart', 'pubspec.yaml']);
            expect(utf8.decode(project.readFile('lib/main.dart')!), contains('void main()'));
            expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: flutter'));
            final state = InitialProjectState.resolve(request, project, sdks);
            expect(state.sdk, sdks.last);
            expect(state.entrypoint, 'lib/main.dart');
          },
          () => MockClient((httpRequest) async {
            expect(httpRequest.url.host, host);
            expect(httpRequest.url.path, '/snippets/material.AppBar.1.dart');
            return http.Response("import 'package:flutter/material.dart';\nvoid main() {}", 200);
          }),
        );
      });
    }

    test('encodes the sample id as one path segment', () {
      const source = FlutterApiDocsProjectSource('nested/sample');
      expect(source.snippetUri.toString(), 'https://api.flutter.dev/snippets/nested%2Fsample.dart');
    });

    test('reports failed snippet downloads', () async {
      await http.runWithClient(
        () => expectLater(
          const FlutterApiDocsProjectSource('missing.Sample').loadProject(),
          throwsException,
        ),
        () => MockClient((_) async => http.Response('Not found', 404)),
      );
    });
  });
  test('maps all flat Gist Dart files and rejects relocation collisions', () async {
    Future<void> check(Map<String, String> files, {bool collision = false}) async {
      await http.runWithClient(
        () async {
          final future = const GistProjectSource('abc').loadProject();
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
        final state = InitialProjectState.resolve(request, await request.source.loadProject(), sdks);
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
