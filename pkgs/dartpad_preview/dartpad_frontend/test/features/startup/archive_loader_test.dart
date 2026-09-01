// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/startup/archive_loader.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('ArchiveLoader', () {
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
      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: 'examples/counter.tar.gz',
        filePath: 'lib/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          await expectLater(loader.loadArchive(api.root), throwsException);
        },
        () => MockClient((http.Request request) async {
          expect(request.url, Uri.base.resolve('examples/counter.tar.gz'));
          return http.Response('Not Found', 404);
        }),
      );
    });

    test('throws Exception if HTTP response is not 200', () async {
      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'lib/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          expect(
            () => loader.loadArchive(api.root),
            throwsException,
          );
        },
        () => MockClient((http.Request request) async {
          return http.Response('Not Found', 404);
        }),
      );
    });

    test('downloads, decompresses .tar.gz, finds pubspec and extracts files', () async {
      final Map<String, String> archiveFiles = {
        'my_project/pubspec.yaml': 'name: my_project\n',
        'my_project/lib/main.dart': 'void main() {}',
        'my_project/lib/src/helper.dart': 'class Helper {}',
        'my_project/assets/image.png': 'binary_content_here',
      };
      final Uint8List archiveBytes = createTarGzArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'my_project/lib/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          final result = await loader.loadArchive(api.root);
          expect(result.projectDir, 'my_project');
          expect(result.entryPath, 'my_project/lib/main.dart');
          expect(result.packageRoot, 'my_project');
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

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'project/lib/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () async {
          await loader.loadArchive(api.root);
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.packageRoot, '');
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.packageRoot, '');
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

    test('disables workspace resolution only for the active nested package', () async {
      const rootPubspec = 'name: root_package\nresolution: workspace\n';
      const examplePubspec = 'name: example_package\nresolution: workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': rootPubspec,
        'example/pubspec.yaml': examplePubspec,
        'example/lib/main.dart': 'void main() {}',
      });
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'example/lib/main.dart',
      );
      final api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.packageRoot, 'example');
      expect(await api.readFileAsText('pubspec.yaml'), rootPubspec);
      expect(await api.readFileAsText('example/pubspec.yaml'), examplePubspec);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(
        await api.readFileAsText('pubspec_overrides.yaml'),
        '{"resolution":null}',
      );
    });

    test('preserves overrides outside the active package', () async {
      const rootOverrides = 'dependency_overrides:\n  collection: any\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': 'name: root\nresolution: workspace\n',
        'pubspec_overrides.yaml': rootOverrides,
        'example/pubspec.yaml': 'name: example\n',
        'example/pubspec_overrides.yaml': 'workspace: []\n',
        'example/lib/main.dart': 'void main() {}',
      });
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'example/lib/main.dart',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsText('pubspec_overrides.yaml'), rootOverrides);
      expect(
        await api.readFileAsText('example/pubspec_overrides.yaml'),
        'workspace: []\n',
      );
    });

    test('preserves a malformed pubspec without creating overrides', () async {
      const pubspec = 'name: package\nresolution: [workspace\n';
      final archiveBytes = createTarArchive({
        'pubspec.yaml': pubspec,
        'README.md': '# Package\n',
      });
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'README.md',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
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
      const loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'pubspec.yaml',
      );
      final api = MemoryWorkspaceResourceApi();

      await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(await api.readFileAsBytes('pubspec.yaml'), [0xFF]);
      expect(await api.fileExist('pubspec_overrides.yaml'), isFalse);
    });

    test('falls back to root folder if no pubspec.yaml is found', () async {
      final Map<String, String> archiveFiles = {
        'my_project/lib/main.dart': 'void main() {}',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'my_project/lib/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.projectDir, '');
      expect(result.entryPath, 'my_project/lib/main.dart');
      expect(result.packageRoot, '');
      expect(result.pathToMain, 'my_project/lib/main.dart');
      expect(await api.fileExist('my_project/lib/main.dart'), isTrue);
      expect(await api.readFileAsText('my_project/lib/main.dart'), 'void main() {}');
    });

    test('defaults pathToMain to filePath when pathToMain is not specified', () async {
      final Map<String, String> archiveFiles = {
        'my_project/pubspec.yaml': 'name: my_project\n',
        'my_project/example/hello.dart': 'void main() {}',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'my_project/example/hello.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'my_project/example/hello.dart');
      expect(result.pathToMain, 'my_project/example/hello.dart');
    });

    test('sets explicit pathToMain when specified', () async {
      final Map<String, String> archiveFiles = {
        'my_project/pubspec.yaml': 'name: my_project\n',
        'my_project/example/hello.dart': 'void hello() {}',
        'my_project/example/main.dart': 'void main() {}',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'my_project/example/hello.dart',
        pathToMain: 'my_project/example/main.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'my_project/example/hello.dart');
      expect(result.pathToMain, 'my_project/example/main.dart');
    });

    test('falls back to root README.md when filePath is not specified', () async {
      final Map<String, String> archiveFiles = {
        'pubspec.yaml': 'name: my_package\n',
        'lib/main.dart': 'void main() {}',
        'README.md': '# My Package\n',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'README.md');
      expect(result.pathToMain, 'README.md');
      expect(result.projectDir, '');
      expect(await api.fileExist('README.md'), isTrue);
      expect(await api.readFileAsText('README.md'), '# My Package\n');
    });

    test('falls back to readme.md when filePath is not specified', () async {
      final Map<String, String> archiveFiles = {
        'pubspec.yaml': 'name: my_package\n',
        'lib/main.dart': 'void main() {}',
        'readme.md': '# Readme Lowercase\n',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'readme.md');
      expect(result.pathToMain, 'readme.md');
      expect(result.projectDir, '');
      expect(await api.fileExist('readme.md'), isTrue);
      expect(await api.readFileAsText('readme.md'), '# Readme Lowercase\n');
    });

    test('prefers example file over README.md when filePath is not specified', () async {
      final Map<String, String> archiveFiles = {
        'pubspec.yaml': 'name: my_package\n',
        'example/main.dart': 'void main() {}',
        'README.md': '# My Package\n',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'example/main.dart');
      expect(result.pathToMain, 'example/main.dart');
    });

    test('finds example/readme.md over root README.md when filePath is not specified', () async {
      final Map<String, String> archiveFiles = {
        'pubspec.yaml': 'name: my_package\n',
        'example/readme.md': '# Example Readme\n',
        'README.md': '# Root Readme\n',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'example/readme.md');
      expect(result.pathToMain, 'example/readme.md');
    });

    test('prefers explicit filePath over example file and README.md', () async {
      final Map<String, String> archiveFiles = {
        'pubspec.yaml': 'name: my_package\n',
        'example/main.dart': 'void main() {}',
        'README.md': '# My Package\n',
        'lib/custom.dart': 'void custom() {}',
      };
      final Uint8List archiveBytes = createTarArchive(archiveFiles);

      const ArchiveLoader loader = ArchiveLoader(
        archiveUrl: absoluteUrl,
        filePath: 'lib/custom.dart',
      );
      final MemoryWorkspaceResourceApi api = MemoryWorkspaceResourceApi();

      final result = await http.runWithClient(
        () => loader.loadArchive(api.root),
        () => MockClient((http.Request request) async {
          return http.Response.bytes(archiveBytes, 200);
        }),
      );

      expect(result.entryPath, 'lib/custom.dart');
      expect(result.pathToMain, 'lib/custom.dart');
    });
  });
}
