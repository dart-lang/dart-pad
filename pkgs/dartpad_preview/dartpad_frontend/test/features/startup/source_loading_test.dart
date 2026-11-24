// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_frontend/features/shared/project_exceptions.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:fake_async/fake_async.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'initial_project_state_test.dart' show sdks;

void main() {
  for (final version in [null, '1.2.3', '1.2.3+build.2']) {
    test('loads ${version ?? 'latest'} package version via metadata archive_url', () async {
      final requests = <Uri>[];
      final archive = Uint8List.fromList(TarEncoder().encode(Archive()));
      final versions = [
        for (final value in ['1.2.3', '1.2.3+build.2', '2.0.0'])
          {
            'version': value,
            'archive_url': 'https://archives.example.com/demo-${Uri.encodeComponent(value)}.tar.gz?token=test',
          },
      ];
      final metadata = versions.singleWhere((entry) => entry['version'] == (version ?? '2.0.0'));
      final archiveUri = Uri.parse(metadata['archive_url']!);
      await http.runWithClient(
        () async {
          final project = await PackageProjectSource('demo', version: version).loadProject();
          expect(project.paths, isEmpty);
        },
        () => MockClient((request) async {
          requests.add(request.url);
          if (request.url == archiveUri) {
            return http.Response.bytes(archive, 200);
          }
          expect(request.url, Uri.https('pub.dev', '/api/packages/demo'));
          expect(request.headers['accept'], 'application/vnd.pub.v2+json');
          return http.Response(jsonEncode({'latest': versions.last, 'versions': versions}), 200);
        }),
      );
      expect(requests, [
        Uri.https('pub.dev', '/api/packages/demo'),
        archiveUri,
      ]);
    });
  }
  test('reports missing package versions without loading latest', () async {
    final requests = <Uri>[];
    await http.runWithClient(
      () async {
        await expectLater(
          const PackageProjectSource('demo', version: '0.0.0').loadProject(),
          throwsA(
            isA<PackageVersionNotFoundException>().having(
              (error) => error.message,
              'message',
              allOf(contains('demo'), contains('0.0.0')),
            ),
          ),
        );
      },
      () => MockClient((request) async {
        requests.add(request.url);
        expect(request.url, Uri.https('pub.dev', '/api/packages/demo'));
        const latest = {'version': '1.2.3', 'archive_url': 'https://pub.dev/api/archives/demo-1.2.3.tar.gz'};
        return http.Response(
          jsonEncode({
            'latest': latest,
            'versions': [latest],
          }),
          200,
        );
      }),
    );
    expect(requests, [Uri.https('pub.dev', '/api/packages/demo')]);
  });
  for (final status in [408, 429, 500, 503, null]) {
    test('retries transient package metadata failure ${status ?? 'network error'}', () {
      return fakeAsync((time) {
        var attempts = 0;
        var completed = false;
        Object? failure;
        final archive = Uint8List.fromList(TarEncoder().encode(Archive()));
        final result = http.runWithClient(
          () => const PackageProjectSource('demo').loadProject(),
          () => MockClient((request) async {
            if (request.url.host == 'archives.example.com') {
              return http.Response.bytes(archive, 200);
            }
            attempts++;
            if (attempts == 1) {
              if (status == null) {
                throw http.ClientException('Network error');
              }
              return http.Response('Temporary failure', status);
            }
            return http.Response(
              jsonEncode({
                'latest': {'archive_url': 'https://archives.example.com/demo.tar'},
              }),
              200,
            );
          }),
        );
        result.then<void>((_) => completed = true, onError: (Object error, StackTrace _) => failure = error);
        time.flushMicrotasks();
        expect(attempts, 1);
        time.elapse(const Duration(seconds: 10));
        expect(attempts, 2);
        expect(failure, isNull);
        expect(completed, isTrue);
      });
    });
  }
  for (final status in [400, 404]) {
    test('does not retry package metadata HTTP $status', () async {
      var attempts = 0;
      await http.runWithClient(
        () => expectLater(
          const PackageProjectSource('demo', version: '1.2.3').loadProject(),
          throwsA(isA<PubPackageMetadataException>().having((error) => error.message, 'message', contains('$status'))),
        ),
        () => MockClient((_) async {
          attempts++;
          return http.Response('Failed', status);
        }),
      );
      expect(attempts, 1);
    });
  }
  for (final status in [503, null]) {
    test('reports package metadata failure after retries: ${status ?? 'network error'}', () {
      return fakeAsync((time) {
        final attempts = <Duration>[];
        Object? failure;
        http
            .runWithClient(
              () => const PackageProjectSource('demo', version: '1.2.3').loadProject(),
              () => MockClient((_) async {
                attempts.add(time.elapsed);
                if (status == null) {
                  throw http.ClientException('Network error');
                }
                return http.Response('Unavailable', status);
              }),
            )
            .then<void>((_) {}, onError: (Object error, StackTrace _) => failure = error);
        time.flushMicrotasks();
        expect(attempts, hasLength(1));
        time.elapse(const Duration(seconds: 10));
        expect(attempts, hasLength(4));
        final delays = [for (var i = 1; i < attempts.length; i++) attempts[i] - attempts[i - 1]];
        expect(delays[0], greaterThan(Duration.zero));
        expect(delays[1], greaterThan(delays[0]));
        expect(delays[2], greaterThan(delays[1]));
        expect(
          failure,
          isA<PubPackageMetadataException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('pub.dev'),
              contains('demo'),
              contains('1.2.3'),
              contains(status?.toString() ?? 'unreachable'),
            ),
          ),
        );
      });
    });
  }
  for (final (version, body) in [
    (null, '{'),
    (null, '[]'),
    (null, '{"latest": {}}'),
    ('1.2.3', '{"versions": {}}'),
    ('1.2.3', '{"versions": [null]}'),
    ('1.2.3', '{"versions": [{}]}'),
    ('1.2.3', '{"versions": [{"version": "1.2.3"}]}'),
  ]) {
    test('reports invalid package metadata for version $version: $body', () async {
      await http.runWithClient(
        () => expectLater(
          PackageProjectSource('demo', version: version).loadProject(),
          throwsA(
            isA<PubPackageMetadataException>().having(
              (error) => error.message,
              'message',
              allOf(contains('pub.dev'), contains('demo'), contains(version ?? 'demo')),
            ),
          ),
        ),
        () => MockClient((_) async => http.Response(body, 200)),
      );
    });
  }
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
            expect(project.paths, ['lib/main.dart']);
            expect(utf8.decode(project.readFile('lib/main.dart')!), contains('void main()'));
            final state = InitialProjectState.resolve(request, project, sdks);
            expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: flutter'));
            expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: ^3.12.0-0'));
            expect(state.hasPubspec, isTrue);
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
          throwsA(isA<ProjectSourceException>()),
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
            await expectLater(future, throwsA(isA<ProjectPathException>()));
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
  test('sample opens its configured file and uses the common SDK resolver', () async {
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
        expect(state.files, ['lib/main.dart']);
        expect(state.entrypoint, 'lib/main.dart');
        expect(state.sdk, sdks.last);
      },
      () => MockClient((request) async {
        expect(request.url.path, endsWith('/examples/counter.tar'));
        return http.Response.bytes(encoded, 200);
      }),
    );
  });
}
