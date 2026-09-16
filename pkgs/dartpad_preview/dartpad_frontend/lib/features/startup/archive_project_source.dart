// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of 'project_source.dart';

/// A tar archive downloaded from a URL, optionally compressed with gzip.
final class ArchiveProjectSource extends ProjectSource {
  /// Describes the archive at [url].
  const ArchiveProjectSource(this.url);

  /// The archive URL, resolved against the page URL when relative.
  final String url;

  @override
  Future<Project> loadProject() => _loadArchive(url);
}

Future<Project> _loadArchive(String archiveUrl) async {
  final Uri uri = Uri.base.resolve(archiveUrl);
  if (!uri.isAbsolute) {
    throw ArgumentError('archiveUrl must resolve to an absolute URI: $archiveUrl');
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
  final project = Project([
    for (final ArchiveFile file in archive.files)
      if (file.isFile)
        ProjectFile(
          path: _relativeArchivePath(file.name),
          bytes: file.content,
        ),
  ]);

  _disableWorkspaceResolution(project);
  return project;
}

/// Isolates packages in the loaded archive from a workspace that is not part
/// of the archive.
///
/// This mirrors `dart pub unpack`: the original pubspec remains unchanged,
/// while `resolution: workspace` is disabled through a package-local
/// `pubspec_overrides.yaml` file.
void _disableWorkspaceResolution(Project project) {
  for (final path in project.paths.toList()) {
    if (basenameWorkspacePath(path) == 'pubspec.yaml') {
      _disableWorkspaceResolutionForPackage(
        project,
        parentWorkspacePath(path),
      );
    }
  }
}

void _disableWorkspaceResolutionForPackage(
  Project project,
  String projectDir,
) {
  final pubspecPath = joinWorkspacePath(projectDir, 'pubspec.yaml');
  final pubspecBytes = project.readFile(pubspecPath);
  if (pubspecBytes == null) {
    return;
  }

  final String pubspecContents;
  try {
    pubspecContents = utf8.decode(pubspecBytes);
  } on FormatException {
    return;
  }

  if (!_usesWorkspaceResolution(pubspecContents)) {
    return;
  }

  final overridesPath = joinWorkspacePath(projectDir, 'pubspec_overrides.yaml');
  project.writeFile(
    overridesPath,
    Uint8List.fromList(utf8.encode(jsonEncode({'resolution': null}))),
  );
}

bool _usesWorkspaceResolution(String pubspecContents) {
  try {
    final Object? rootValue = loadYaml(pubspecContents);
    return rootValue is Map<Object?, Object?> && rootValue['resolution'] == 'workspace';
  } on YamlException {
    return false;
  }
}

String _relativeArchivePath(String path) {
  if (path.startsWith('./')) {
    return path.substring(2);
  }
  return path;
}
