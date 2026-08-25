// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/startup/example_project.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  Uint8List counterArchive() {
    final pubspec = 'name: counter\n'.codeUnits;
    final main = 'void main() {}\n'.codeUnits;
    final archive = Archive()
      ..addFile(ArchiveFile('pubspec.yaml', pubspec.length, pubspec))
      ..addFile(ArchiveFile('lib/main.dart', main.length, main));
    return Uint8List.fromList(const GZipEncoder().encode(TarEncoder().encode(archive)));
  }

  test('throws ArgumentError for an unknown sample ID', () async {
    final api = MemoryWorkspaceResourceApi();

    await expectLater(
      http.runWithClient(
        () => loadSampleProject(
          api.root,
          sampleId: 'unknown-sample',
        ),
        () => MockClient((_) async => http.Response.bytes(counterArchive(), 200)),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('throws when the sample archive is unavailable', () async {
    final api = MemoryWorkspaceResourceApi();

    await expectLater(
      http.runWithClient(
        () => loadSampleProject(api.root, sampleId: 'dart'),
        () => MockClient((_) async => http.Response('Not Found', 404)),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('loads a valid sample successfully', () async {
    final api = MemoryWorkspaceResourceApi();

    final project = await http.runWithClient(
      () => loadSampleProject(api.root),
      () => MockClient((_) async => http.Response.bytes(counterArchive(), 200)),
    );

    expect(project.entryPath, 'lib/main.dart');
  });
}
