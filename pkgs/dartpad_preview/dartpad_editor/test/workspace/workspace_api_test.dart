// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryWorkspaceResourceApi', () {
    late MemoryWorkspaceResourceApi api;

    setUp(() {
      api = MemoryWorkspaceResourceApi();
    });

    test('performs file/folder existence operations correctly', () async {
      expect(await api.fileExist('a.dart'), isFalse);
      expect(await api.folderExist('src'), isFalse);

      await api.createFolder('src');
      expect(await api.folderExist('src'), isTrue);

      await api.writeFileFromText('src/a.dart', 'hello');
      expect(await api.fileExist('src/a.dart'), isTrue);
      expect(await api.readFileAsText('src/a.dart'), 'hello');

      await api.deleteFileSystemEntity('src/a.dart');
      expect(await api.fileExist('src/a.dart'), isFalse);
    });

    test('listDirectory behaves correctly', () async {
      await api.createFolder('lib');
      await api.createFolder('lib/src');
      await api.writeFileFromText('lib/a.dart', 'a');
      await api.writeFileFromText('lib/src/b.dart', 'b');

      final nonRecursive = await api.listDirectory(uri: 'lib', recursive: false);
      expect(nonRecursive, hasLength(2));
      expect(
        nonRecursive.map((e) => e.path),
        containsAll(['src', 'a.dart']),
      );

      final recursive = await api.listDirectory(uri: 'lib', recursive: true);
      expect(recursive, hasLength(3));
    });

    test('reconciles file change events', () async {
      final eventsFuture = api.changeEvents.take(1).toList();

      await api.writeFileFromText('test.dart', 'test');
      final events = await eventsFuture;

      expect(events, hasLength(1));
      expect(events.first.type, WorkspaceChangeEventType.add);
      expect(events.first.path, 'test.dart');
    });
  });
}
