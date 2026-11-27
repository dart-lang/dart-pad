// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// A pub.dev package loads into a folder named after the package, so example
// path dependencies on the package resolve as in a checkout of its source.
// See https://github.com/dart-lang/dart-pad/issues/4058.

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dartpad_editor/dartpad_editor.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

const sdks = [SdkInfo(id: 'dart', name: 'Dart', path: 'dart/', dartVersion: '3.12.0')];

const examplePubspec =
    'name: mesh_gradient_example\n'
    'dependencies:\n'
    '  mesh_gradient:\n'
    '    path: ./../../mesh_gradient\n';

/// The layout of the mesh_gradient 1.3.8 archive from pub.dev, which has no
/// top-level folder.
const meshGradientArchive = {
  'pubspec.yaml': 'name: mesh_gradient\n',
  'README.md': '# mesh_gradient\n',
  'lib/main.dart': 'void main() {}\n',
  'example/pubspec.yaml': examplePubspec,
  'example/lib/main.dart': 'void main() {}\n',
};

Uint8List tarOf(Map<String, String> files) {
  final archive = Archive();
  for (final file in files.entries) {
    final bytes = utf8.encode(file.value);
    archive.addFile(ArchiveFile(file.key, bytes.length, bytes));
  }
  return Uint8List.fromList(TarEncoder().encode(archive));
}

Future<Project> load(ProjectSource source) => http.runWithClient(
  source.loadProject,
  () => MockClient((request) async {
    if (request.url.host == 'pub.dev') {
      return http.Response(
        jsonEncode({
          'latest': {'version': '1.3.8', 'archive_url': 'https://archives.example.com/mesh_gradient.tar'},
        }),
        200,
      );
    }
    return http.Response.bytes(tarOf(meshGradientArchive), 200);
  }),
);

Future<InitialProjectState> resolve(String query) async {
  final request = ProjectRequest.fromUri(Uri.parse(query));
  return InitialProjectState.resolve(request, await load(request.source), sdks);
}

void main() {
  group('PackageProjectSource', () {
    test('places the archive in a folder named after the package', () async {
      final project = await load(const PackageProjectSource('mesh_gradient'));

      expect(project.sourceRoot, 'mesh_gradient');
      expect(project.paths, unorderedEquals(meshGradientArchive.keys.map((path) => 'mesh_gradient/$path')));
    });

    test('keeps the example path dependency on the package unchanged', () async {
      final project = await load(const PackageProjectSource('mesh_gradient'));

      expect(utf8.decode(project.readFile('mesh_gradient/example/pubspec.yaml')!), examplePubspec);
      expect(project.paths.where((path) => path.endsWith('.original.dartpad.yaml')), isEmpty);
    });

    test('resolves the example path dependency to the package', () async {
      final project = await load(const PackageProjectSource('mesh_gradient'));
      final target = joinWorkspacePath('mesh_gradient/example', './../../mesh_gradient');

      expect(target, 'mesh_gradient');
      expect(project.containsFile(joinWorkspacePath(target, 'pubspec.yaml')), isTrue);
      // pub resolves the path in the worker's workspace folder.
      expect(
        Uri.parse('file:///workspace/pad_42/mesh_gradient/example/').resolve('./../../mesh_gradient'),
        Uri.parse('file:///workspace/pad_42/mesh_gradient'),
      );
    });
  });

  test('ArchiveProjectSource keeps the archive at the workspace root', () async {
    final project = await load(const ArchiveProjectSource('https://archives.example.com/mesh_gradient.tar'));

    expect(project.sourceRoot, isEmpty);
    expect(project.paths, unorderedEquals(meshGradientArchive.keys));
  });

  group('package URL parameters are relative to the package folder', () {
    test('without file or root, opens the package README', () async {
      final state = await resolve('?package=mesh_gradient');

      expect(state.root, 'mesh_gradient');
      expect(state.files, ['mesh_gradient/README.md']);
      expect(state.entrypoint, 'mesh_gradient/lib/main.dart');
    });

    test('file', () async {
      final state = await resolve('?package=mesh_gradient&file=example/lib/main.dart');

      expect(state.root, 'mesh_gradient/example');
      expect(state.files, ['mesh_gradient/example/lib/main.dart']);
      expect(state.entrypoint, 'mesh_gradient/example/lib/main.dart');
    });

    test('entrypoint', () async {
      final state = await resolve('?package=mesh_gradient&entrypoint=example/lib/main.dart');

      expect(state.root, 'mesh_gradient/example');
      expect(state.entrypoint, 'mesh_gradient/example/lib/main.dart');
    });

    test('root', () async {
      final state = await resolve('?package=mesh_gradient&root=example');

      expect(state.root, 'mesh_gradient/example');
      expect(state.entrypoint, 'mesh_gradient/example/lib/main.dart');
    });
  });
}
