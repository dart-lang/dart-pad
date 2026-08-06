// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:http/http.dart' as http;

/// A loader that downloads a (gzipped) tar archive from a remote URL,
/// extracts all of its files into a virtual workspace folder, and opens a
/// target file.
class ArchiveLoader {
  /// Creates an archive loader.
  const ArchiveLoader({
    required this.archiveUrl,
    this.packageName,
    this.filePath,
  });

  static Future<ArchiveLoader> forPackage(String packageName) async {
    final String url = 'https://pub.dev/api/packages/$packageName';
    final http.Response response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load package $packageName');
    }

    final Map<String, Object?> json = jsonDecode(response.body) as Map<String, Object?>;
    if (json case {'latest': {'archive_url': final String archiveUrl}}) {
      return ArchiveLoader(archiveUrl: archiveUrl, packageName: packageName);
    }

    throw Exception('Failed to load package $packageName: Unexpected JSON response.');
  }

  /// The absolute URL pointing to the tar or gzipped tar archive.
  final String archiveUrl;

  /// The name of the package that the archive belongs to.
  final String? packageName;

  /// The workspace-relative file path within the project to open after extraction.
  final String? filePath;

  /// Downloads, decompresses, and extracts all files from the [archiveUrl]
  /// into the workspace [root].
  ///
  /// Scans the archive files to find the nearest parent directory containing
  /// a `pubspec.yaml` file for the active target file.
  ///
  /// Returns a record containing:
  /// - `projectDir`: The path to the project directory relative to the archive root.
  /// - `targetFilePath`: The path to the file to open after extraction, which is
  ///   either the provided [filePath] or resolved by searching the archive for
  ///   well-known example files.
  Future<({String projectDir, String? targetFilePath})> loadArchive(WorkspaceFolder root) async {
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

    final targetFilePath = filePath ?? findExampleFile(archive);
    String projectDir = '';

    if (targetFilePath != null) {
      final String normalizedFilePath = workspaceContext.normalize(targetFilePath);
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

      for (int i = segments.length - 1; i >= 0; i--) {
        final String parentDir = segments.sublist(0, i).join('/');
        final String pubspecPath = parentDir.isEmpty ? 'pubspec.yaml' : '$parentDir/pubspec.yaml';
        if (archivePaths.contains(pubspecPath)) {
          projectDir = parentDir;
          break;
        }
      }
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

    return (projectDir: projectDir, targetFilePath: targetFilePath);
  }

  /// Finds the example file in the archive, returning null if not found.
  String? findExampleFile(Archive archive) {
    final List<String> exampleFilenames = [
      'example/main.dart',
      'example/lib/main.dart',
      if (packageName != null) ...[
        'example/$packageName.dart',
        'example/lib/$packageName.dart',
        'example/${packageName}_example.dart',
        'example/lib/${packageName}_example.dart',
      ],
      'example/example.dart',
      'example/lib/example.dart',
      'example/example.md',
      'example/README.md',
    ];

    for (final String exampleFilename in exampleFilenames) {
      final ArchiveFile? file = archive.find(exampleFilename);
      if (file != null) {
        return exampleFilename;
      }
    }

    return null;
  }
}
