// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('ArchiveProjectSource', () {
    const String absoluteUrl = 'https://example.com/archive.tar.gz';

    Uint8List createTarArchiveFromBytes(Map<String, List<int>> files) {
      final Archive archive = Archive();
      for (final entry in files.entries) {
        archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
      }
      final List<int> encoded = TarEncoder().encode(archive);
      return Uint8List.fromList(encoded);
    }

    Uint8List createTarArchive(Map<String, String> files) {
      return createTarArchiveFromBytes(
        files.map((path, contents) => MapEntry(path, contents.codeUnits)),
      );
    }

    Uint8List createTarGzArchive(Map<String, String> files) {
      final Uint8List tarBytes = createTarArchive(files);
      final List<int> encoded = const GZipEncoder().encode(tarBytes);
      return Uint8List.fromList(encoded);
    }

    test('comments out dependencies absent from the imported workspace', () async {
      const pubspec = '''
name: material_ui
dependencies:
  flutter:
    sdk: flutter
  local:
    path: packages/local
  missing:
    path: packages/missing
dev_dependencies:
  flutter_goldens:
    path: ../../script/flutter_goldens
  remote:
    git:
      url: https://example.com/remote.git
      ref: main
dependency_overrides:
  external: {path: ../external}
''';
      final archive = createTarArchive({
        'pubspec.yaml': pubspec,
        'packages/local/pubspec.yaml': 'name: local\n',
      });
      final api = MemoryWorkspaceResourceApi();
      addTearDown(api.dispose);
      await http.runWithClient(
        () => loadInto(const ArchiveProjectSource(absoluteUrl), api.root),
        () => MockClient((_) async => http.Response.bytes(archive, 200)),
      );
      final contents = await api.readFileAsText('pubspec.yaml');
      final yaml = loadYaml(contents) as YamlMap;
      expect((yaml['dependencies'] as YamlMap).keys, ['flutter', 'local']);
      expect(yaml['dev_dependencies'], isEmpty);
      expect(yaml['dependency_overrides'], isEmpty);
      expect(contents, contains('# flutter_goldens: # stripped by DartPad'));
      expect(contents, contains('#     path: ../../script/flutter_goldens'));
      expect(contents, contains('#       url: https://example.com/remote.git'));
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
    });

    test('preserves parent and sibling packages and warns about unavailable dependencies', () async {
      const pubspec = '''
name: example
dependencies:
  parent: {path: ..}
  sibling: {path: ../../sibling}
  missing: {path: ../../missing}
dev_dependencies:
  flutter_goldens:
    path: ../../../script/flutter_goldens
  remote: {git: https://example.com/remote.git}
''';
      final archive = createTarArchive({
        'packages/root/pubspec.yaml': 'name: parent\n',
        'packages/root/example/pubspec.yaml': pubspec,
        'packages/sibling/pubspec.yaml': 'name: sibling\n',
        'packages/root/example/pubspec_overrides.yaml': 'dependency_overrides:\n  outside: {path: /external}\n',
      });
      final project = await http.runWithClient(
        () => const ArchiveProjectSource(absoluteUrl).loadProject(),
        () => MockClient((_) async => http.Response.bytes(archive, 200)),
      );
      final yaml = loadYaml(String.fromCharCodes(project.readFile('packages/root/example/pubspec.yaml')!)) as YamlMap;
      expect((yaml['dependencies'] as YamlMap).keys, ['parent', 'sibling']);
      expect(project.importWarnings, hasLength(4));
      expect(project.importWarnings.join('\n'), contains('Dependency "flutter_goldens"'));
      expect(project.importWarnings.join('\n'), contains('outside the imported workspace'));
      expect(project.importWarnings.join('\n'), contains('uses Git'));
      expect(project.importWarnings.every((warning) => warning.endsWith('was not loaded.')), isTrue);
      expect(project.importWarnings.join('\n'), contains('packages/root/example/pubspec_overrides.yaml'));
    });

    for (final (name, pubspec) in [
      (
        'flow section',
        'name: example\ndependencies: {keep: any, outside: {path: ../outside}, remote: {git: https://example.com/repo.git}}\n',
      ),
      (
        'flow document',
        '{name: example, dependencies: {keep: any, outside: {path: ../outside}, remote: {git: https://example.com/repo.git}}}',
      ),
      (
        'CRLF block',
        'name: example\r\ndependencies:\r\n  keep: any\r\n  outside: {path: ../outside}\r\n  remote: {git: https://example.com/repo.git}',
      ),
    ]) {
      test('retains valid YAML when commenting out dependencies in a $name', () async {
        final archive = createTarArchive({'pubspec.yaml': pubspec});
        final project = await http.runWithClient(
          () => const ArchiveProjectSource(absoluteUrl).loadProject(),
          () => MockClient((_) async => http.Response.bytes(archive, 200)),
        );
        final text = String.fromCharCodes(project.readFile('pubspec.yaml')!);
        final yaml = loadYaml(text) as YamlMap;
        expect(yaml['name'], 'example');
        expect((yaml['dependencies'] as YamlMap).keys, ['keep']);
        expect(text, contains('stripped by DartPad'));
        expect(text, contains('../outside'));
        expect(text, contains('https://example.com/repo.git'));
        expect(project.importWarnings, hasLength(2));
      });
    }

    for (final (position, dependencies) in [
      ('first', "{outside: {path: '../outside'}, 'keep' : '^1.0.0',}"),
      ('middle', "{'keep' : '^1.0.0', outside: {path: '../outside'}, local: { path: 'local' }}"),
      ('last', "{'keep' : '^1.0.0', outside: {path: '../outside'}}"),
      (
        'separated',
        "{remote: {git: 'https://example.com/repo.git'}, 'keep' : '^1.0.0', outside: {path: '../outside'}}",
      ),
      (
        'adjacent',
        "{'keep' : '^1.0.0', remote: {git: 'https://example.com/repo.git'}, outside: {path: '../outside'},}",
      ),
      ('all', "{remote: {git: 'https://example.com/repo.git'}, outside: {path: '../outside'},}"),
      (
        'multiline',
        '''{
  'keep' : '^1.0.0', # Preserve this comment, including its comma.
  outside: {path: '../outside'},
  local: { path: 'local' },
}''',
      ),
      (
        'commented separator',
        '''{
  'keep' : '^1.0.0' # Preserve this comment, including its comma.
  , outside: {path: '../outside'}
}''',
      ),
    ]) {
      test('preserves flow-map source formatting when stripping $position entries', () async {
        final pubspec = 'name: example\ndependencies: $dependencies # Keep the section comment.\n';
        final archive = createTarArchive({
          'pubspec.yaml': pubspec,
          'local/pubspec.yaml': 'name: local\n',
        });
        final project = await http.runWithClient(
          () => const ArchiveProjectSource(absoluteUrl).loadProject(),
          () => MockClient((_) async => http.Response.bytes(archive, 200)),
        );
        final text = String.fromCharCodes(project.readFile('pubspec.yaml')!);
        final yaml = loadYaml(text) as YamlMap;
        final retained = yaml['dependencies'] as YamlMap;
        expect(retained.containsKey('outside'), isFalse);
        expect(retained.containsKey('remote'), isFalse);
        expect(text, contains("# outside: {path: '../outside'} # stripped by DartPad"));
        expect(text, contains('# Keep the section comment.'));
        if (position != 'all') {
          expect(retained['keep'], '^1.0.0');
          expect(text, contains("'keep' : '^1.0.0'"));
        }
        if (dependencies.contains('# Preserve')) {
          expect(text, contains('# Preserve this comment,'));
        }
        if (position == 'multiline') {
          expect(text, contains("local: { path: 'local' }"));
        }
      });
    }

    for (final compressed in [false, true]) {
      test('imports file-sized buffers for worker messages, compressed=$compressed', () async {
        final files = {
          'lib/main.dart': [0, 127, 255],
          'assets/data.bin': List<int>.filled(4096, 42),
          'empty.txt': <int>[],
        };
        final tar = createTarArchiveFromBytes(files);
        final archiveBytes = compressed ? const GZipEncoder().encode(tar) : tar;
        final api = MemoryWorkspaceResourceApi();
        addTearDown(api.dispose);

        await http.runWithClient(
          () => loadInto(const ArchiveProjectSource(absoluteUrl), api.root),
          () => MockClient((_) async => http.Response.bytes(archiveBytes, 200)),
        );

        for (final entry in files.entries) {
          final bytes = await api.readFileAsBytes(entry.key);
          expect(bytes, entry.value);
          // MessagePort clones the entire backing buffer, including bytes
          // outside the view. Sending a file must not copy the whole archive.
          expect(bytes.buffer.lengthInBytes, bytes.lengthInBytes, reason: entry.key);
        }
      });
    }

    test('retains distinct files across tar buffers and native gzip chunks', () async {
      final files = {
        for (var i = 0; i < 8; i++) 'file$i.bin': List<int>.generate(70001 + i, (offset) => (offset + i) % 256),
      };
      final archive = const GZipEncoder().encode(createTarArchiveFromBytes(files));
      final project = await http.runWithClient(
        () => const ArchiveProjectSource(absoluteUrl).loadProject(),
        () => MockClient((_) async => http.Response.bytes(archive, 200)),
      );
      for (final entry in files.entries) {
        expect(project.readFile(entry.key), entry.value, reason: entry.key);
        expect(project.readFile(entry.key)!.buffer.lengthInBytes, entry.value.length);
      }
    });

    test('accepts gzip archives with trailing zero padding', () async {
      final archive = createTarGzArchive({'README.md': '# Padded archive'});
      final project = await http.runWithClient(
        () => const ArchiveProjectSource(absoluteUrl).loadProject(),
        () => MockClient((_) async => http.Response.bytes([...archive, ...List<int>.filled(512, 0)], 200)),
      );
      expect(project.readFile('README.md'), '# Padded archive'.codeUnits);
    });

    for (final damage in ['checksum', 'truncated', 'invalid tar']) {
      test('rejects $damage archives', () async {
        final tar = createTarArchive({'README.md': '# Invalid archive'});
        final gzip = createTarGzArchive({'README.md': '# Invalid archive'});
        final damaged = switch (damage) {
          'checksum' => Uint8List.fromList(gzip)..[gzip.length - 8] ^= 1,
          'truncated' => gzip.sublist(0, gzip.length - 4),
          _ => Uint8List.fromList(tar)..[0] ^= 1,
        };
        await http.runWithClient(
          () => expectLater(const ArchiveProjectSource(absoluteUrl).loadProject(), throwsA(anything)),
          () => MockClient((_) async => http.Response.bytes(damaged, 200)),
        );
      });
    }

    test('resolves a relative URL against the page URL', () async {
      const ArchiveProjectSource source = ArchiveProjectSource(
        'examples/counter.tar.gz',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          await expectLater(loadInto(source, api.root), throwsException);
        },
        () => MockClient((http.Request request) async {
          expect(request.url, Uri.base.resolve('examples/counter.tar.gz'));
          return http.Response('Not Found', 404);
        }),
      );
    });

    test('throws Exception if HTTP response is not 200', () async {
      const ArchiveProjectSource source = ArchiveProjectSource(
        absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          expect(
            () => loadInto(source, api.root),
            throwsException,
          );
        },
        () => MockClient((http.Request request) async {
          return http.Response('Not Found', 404);
        }),
      );
    });

    test('downloads, decompresses .tar.gz and imports all files', () async {
      final Map<String, String> archiveFiles = {
        'my_project/pubspec.yaml': 'name: my_project\n',
        'my_project/lib/main.dart': 'void main() {}',
        'my_project/lib/src/helper.dart': 'class Helper {}',
        'my_project/assets/image.png': 'binary_content_here',
      };
      final Uint8List archiveBytes = createTarGzArchive(archiveFiles);

      const ArchiveProjectSource source = ArchiveProjectSource(
        absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          await loadInto(source, api.root);
        },
        () => MockClient((http.Request request) async {
          expect(request.url.toString(), absoluteUrl);
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      // Verify that the files were extracted under the workspace root, relative to the project root 'my_project/'
      expect(await api.fileExist('my_project/pubspec.yaml'), isTrue);
      expect(await api.fileExist('my_project/lib/main.dart'), isTrue);
      expect(await api.fileExist('my_project/lib/src/helper.dart'), isTrue);
      expect(await api.fileExist('my_project/assets/image.png'), isTrue);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
      expect(await api.fileExist('my_project/pubspec_overrides.yaml'), isFalse);

      // Verify content
      expect(await api.readFileAsText('my_project/pubspec.yaml'), 'name: my_project\n');
      expect(await api.readFileAsText('my_project/lib/main.dart'), 'void main() {}');
      expect(await api.readFileAsText('my_project/lib/src/helper.dart'), 'class Helper {}');
    });

    test('downloads and extracts uncompressed .tar files', () async {
      final Map<String, String> archiveFiles = {
        'project/pubspec.yaml': 'name: project\n',
        'project/lib/main.dart': 'void main() {}',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveProjectSource source = ArchiveProjectSource(
        absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          await loadInto(source, api.root);
        },
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.fileExist('project/pubspec.yaml'), isTrue);
      expect(await api.fileExist('project/lib/main.dart'), isTrue);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
      expect(await api.fileExist('project/pubspec_overrides.yaml'), isFalse);
    });

    test('disables workspace resolution for the active root package', () async {
      const pubspec = 'name: root_package\nresolution: workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': pubspec,
        'README.md': '# Root package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec.yaml'), pubspec);
      expect(
        await api.readFileAsText('pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('also isolates an example package resolved by Pub', () async {
      const rootPubspec = 'name: root_package\nresolution: workspace\n';
      const examplePubspec = 'name: example_package\nresolution: workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': rootPubspec,
        'README.md': '# Root package\n',
        'example/pubspec.yaml': examplePubspec,
        'example/lib/main.dart': 'void main() {}',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec.yaml'), rootPubspec);
      expect(await api.readFileAsText('example/pubspec.yaml'), examplePubspec);
      expect(
        await api.readFileAsText('pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
      expect(
        await api.readFileAsText('example/pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('disables workspace resolution across all packages in the archive', () async {
      const rootPubspec = 'name: root_package\nresolution: workspace\n';
      const examplePubspec = 'name: example_package\nresolution: workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': rootPubspec,
        'example/pubspec.yaml': examplePubspec,
        'example/lib/main.dart': 'void main() {}',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec.yaml'), rootPubspec);
      expect(await api.readFileAsText('example/pubspec.yaml'), examplePubspec);
      expect(
        await api.readFileAsText('pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
      expect(
        await api.readFileAsText('example/pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('replaces an existing overrides file for the active package', () async {
      const overrides = '''
# Preserve this comment.
dependency_overrides:
  collection: ^1.19.0
workspace:
  - packages/*
resolution: workspace
''';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': 'name: package\nresolution: workspace\n',
        'pubspec_overrides.yaml': overrides,
        'README.md': '# Package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      final updated = await api.readFileAsText('pubspec_overrides.yaml');
      expect(updated, '{"resolution":null}');
    });

    test('replaces an empty overrides file', () async {
      final archiveBytes = createTarArchive({
        'pubspec.yaml': 'name: package\nresolution: workspace\n',
        'pubspec_overrides.yaml': '',
        'README.md': '# Package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      final updated = await api.readFileAsText('pubspec_overrides.yaml');
      expect(updated, '{"resolution":null}');
    });

    test('replaces an invalid overrides file', () async {
      const overrides = '- not a map\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': 'name: package\nresolution: workspace\n',
        'pubspec_overrides.yaml': overrides,
        'README.md': '# Package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(
        await api.readFileAsText('pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('preserves overrides for packages not using workspace resolution', () async {
      const rootOverrides = 'dependency_overrides:\n  collection: any\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': 'name: root\n',
        'pubspec_overrides.yaml': rootOverrides,
        'example/pubspec.yaml': 'name: example\nresolution: workspace\n',
        'example/pubspec_overrides.yaml': 'workspace: []\n',
        'example/lib/main.dart': 'void main() {}',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec_overrides.yaml'), rootOverrides);
      expect(
        await api.readFileAsText('example/pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('disables workspace resolution across arbitrary nested package directories', () async {
      final archiveBytes = createTarArchive({
        'packages/pkg_a/pubspec.yaml': 'name: pkg_a\nresolution: workspace\n',
        'packages/pkg_b/pubspec.yaml': 'name: pkg_b\n',
        'packages/nested/pkg_c/pubspec.yaml': 'name: pkg_c\nresolution: workspace\n',
        'README.md': '# Multi-package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(
        await api.readFileAsText('packages/pkg_a/pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
      expect(
        await api.fileExist('packages/pkg_b/pubspec_overrides.yaml'),
        isFalse,
      );
      expect(
        await api.readFileAsText('packages/nested/pkg_c/pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('preserves a malformed pubspec without creating overrides', () async {
      const pubspec = 'name: package\nresolution: [workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': pubspec,
        'README.md': '# Package\n',
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec.yaml'), pubspec);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
    });

    test('preserves a non-UTF-8 pubspec without creating overrides', () async {
      final archiveBytes = createTarArchiveFromBytes({
        'pubspec.yaml': [0xFF],
      });
      const source = ArchiveProjectSource(
        absoluteUrl,
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loadInto(source, api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsBytes('pubspec.yaml'), [0xFF]);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
    });
  });
}

Future<void> loadInto(ArchiveProjectSource source, WorkspaceFolder root) async {
  await ProjectLoader.writeFiles(root, await source.loadProject());
}
