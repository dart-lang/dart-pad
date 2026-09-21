// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
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
    await expectLater(
      http.runWithClient(
        () => const SampleProjectSource('unknown-sample').loadProject(),
        () => MockClient((_) async => http.Response.bytes(counterArchive(), 200)),
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('throws when the sample archive is unavailable', () async {
    await expectLater(
      http.runWithClient(
        () => const SampleProjectSource('dart').loadProject(),
        () => MockClient((_) async => http.Response('Not Found', 404)),
      ),
      throwsA(isA<Exception>()),
    );
  });

  test('loads a valid sample successfully', () async {
    final project = await http.runWithClient(
      const SampleProjectSource().loadProject,
      () => MockClient((_) async => http.Response.bytes(counterArchive(), 200)),
    );

    expect(project.containsFile('lib/main.dart'), isTrue);
  });
}
