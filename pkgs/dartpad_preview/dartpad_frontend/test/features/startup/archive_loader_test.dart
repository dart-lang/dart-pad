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
