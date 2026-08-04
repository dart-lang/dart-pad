// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;

class ArchiveLoader {
  const ArchiveLoader({
    required this.archiveUrl,
    required this.filePath,
    this.mainPath,
  });

  final String archiveUrl;
  final String filePath;
  final String? mainPath;

  Future<String> loadArchive(WorkspaceFolder root, Future<void> Function(String path) openFile) async {
    final Uri uri = Uri.parse(archiveUrl);
    if (!uri.isAbsolute) {
      throw ArgumentError('archiveUrl must be absolute: $archiveUrl');
    }

    final http.Response response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load archive');
    }

    final Uint8List bytes = response.bodyBytes;
    List<int> tarBytes = bytes;
    if (bytes.length >= 2 && bytes[0] == 0x1F && bytes[1] == 0x8B) {
      tarBytes = const GZipDecoder().decodeBytes(bytes);
    }

    final Archive archive = TarDecoder().decodeBytes(tarBytes);

    final String normalizedFilePath = workspaceContext.normalize(filePath);
    final Set<String> archivePaths = <String>{};
    for (final ArchiveFile file in archive.files) {
      String name = file.name;
      if (name.startsWith('./')) {
        name = name.substring(2);
      } else if (name.startsWith('/')) {
        name = name.substring(1);
      }
      archivePaths.add(name);
    }

    final List<String> segments = normalizedFilePath.split('/');
    String? rootProjectDir;

    for (int i = segments.length - 1; i >= 0; i--) {
      final String parentDir = segments.sublist(0, i).join('/');
      final String pubspecPath = parentDir.isEmpty ? 'pubspec.yaml' : '$parentDir/pubspec.yaml';
      if (archivePaths.contains(pubspecPath)) {
        rootProjectDir = parentDir;
        break;
      }
    }

    if (rootProjectDir == null) {
      throw Exception('Could not find pubspec.yaml in any parent directory of $filePath');
    }

    final List<ArchiveFile> filesToExtract = <ArchiveFile>[];
    final Set<String> foldersToCreate = <String>{};

    for (final ArchiveFile file in archive.files) {
      if (!file.isFile) {
        continue;
      }

      String name = file.name;
      if (name.startsWith('./')) {
        name = name.substring(2);
      } else if (name.startsWith('/')) {
        name = name.substring(1);
      }

      filesToExtract.add(file);

      String dir = workspaceContext.dirname(name);
      while (dir.isNotEmpty && dir != '.') {
        foldersToCreate.add(dir);
        dir = workspaceContext.dirname(dir);
      }
    }

    final List<String> sortedFolders = foldersToCreate.toList()
      ..sort((String a, String b) => a.length.compareTo(b.length));
    for (final String folderPath in sortedFolders) {
      await root.getFolder(folderPath).create();
    }

    for (final ArchiveFile file in filesToExtract) {
      String name = file.name;
      if (name.startsWith('./')) {
        name = name.substring(2);
      } else if (name.startsWith('/')) {
        name = name.substring(1);
      }

      final dynamic content = file.content;
      final Uint8List fileBytes = content is Uint8List ? content : Uint8List.fromList(content as List<int>);

      await root.workspace.writeFileFromBytes(root.getFile(name).path, fileBytes);
    }

    await openFile(normalizedFilePath);
    return rootProjectDir;
  }
}
