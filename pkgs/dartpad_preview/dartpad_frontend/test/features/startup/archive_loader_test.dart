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

    Uint8List createTarArchive(Map<String, String> files) {
      final Archive archive = Archive();
      for (final MapEntry<String, String> entry in files.entries) {
        final List<int> contentBytes = entry.value.codeUnits;
        archive.addFile(ArchiveFile(entry.key, contentBytes.length, contentBytes));
      }
      final List<int> encoded = TarEncoder().encode(archive);
      return Uint8List.fromList(encoded);
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
  });
}
