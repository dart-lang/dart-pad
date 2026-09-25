// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/features/shared/dart_source.dart';
import 'package:dartpad_frontend/features/shared/sdk_info.dart';
import 'package:dartpad_frontend/features/startup/initial_project_state.dart';
import 'package:dartpad_frontend/features/startup/project_loader.dart';
import 'package:dartpad_frontend/features/startup/project_request.dart';
import 'package:dartpad_frontend/features/startup/project_source.dart';
import 'package:test/test.dart';

const sdks = [
  SdkInfo(id: 'dart', name: 'Dart', path: 'dart/', dartVersion: '3.12.0'),
  SdkInfo(id: 'flutter', name: 'Flutter', path: 'flutter/', dartVersion: '3.12.0', flutterVersion: '3.44.0'),
];

Project contents(Map<String, String> files, {Map<String, String> mapping = const {}}) => Project([
  for (final file in files.entries) ProjectFile(path: file.key, bytes: Uint8List.fromList(utf8.encode(file.value))),
], pathMapping: mapping);

InitialProjectState resolve(String query, Map<String, String> files) =>
    InitialProjectState.resolve(ProjectRequest.fromUri(Uri.parse(query)), contents(files), sdks);

void main() {
  group('ProjectRequest', () {
    test('preserves repeated files and decodes URL components exactly once', () {
      final uri = Uri(
        queryParameters: {
          'url': 'https://example.com/a%20b.tar?token=a+b&part=1',
          'file': ['lib/a b.dart', 'lib/100%.dart'],
          'embed': 'true',
        },
      );
      final request = ProjectRequest.fromUri(uri);
      expect((request.source as ArchiveProjectSource).url, 'https://example.com/a%20b.tar?token=a+b&part=1');
      expect(request.files, ['lib/a b.dart', 'lib/100%.dart']);
      expect(Uri.parse(request.search).queryParametersAll, uri.queryParametersAll);
      expect(() => request.files.add('x'), throwsUnsupportedError);
      expect(() => request.query['file']!.add('x'), throwsUnsupportedError);
    });

    test('types all sources', () {
      expect(ProjectRequest.example().source, isA<SampleProjectSource>());
      final package = ProjectRequest.fromUri(Uri.parse('?package=foo&version=1.2.3')).source as PackageProjectSource;
      expect(package.version, '1.2.3');
      expect((ProjectRequest.fromUri(Uri.parse('?id=abc')).source as GistProjectSource).id, 'abc');
      expect((ProjectRequest.fromUri(Uri.parse('?gist=abc')).source as GistProjectSource).id, 'abc');
      final apiDocs =
          ProjectRequest.fromUri(
                Uri.parse('?sample_id=material.AppBar.1&channel=stable'),
              ).source
              as FlutterApiDocsProjectSource;
      expect(apiDocs.sampleId, 'material.AppBar.1');
      expect(apiDocs.channel, 'stable');
    });

    test('parses legacy Flutter embed presentation options after the HTML redirect', () {
      final request = ProjectRequest.fromUri(
        Uri.parse('/?sample_id=material.AppBar.1&channel=stable&split=60&run=true&embed=true'),
      );

      expect(request.isLegacyEmbedMode, isTrue);
      expect(request.isEmbedMode, isTrue);
      expect(request.autoRun, isTrue);
      expect(request.initialSplitRatio, 0.6);
      expect(request.sdk, isNull);
      expect(request.sdkVersion, isNull);
      expect(ProjectRequest.isEmbedUri(Uri.parse('/?sample=counter&embed=true')), isTrue);
    });

    test('documentation sample selection does not imply embed presentation or an SDK', () {
      for (final (embedQuery, embedded) in [('', false), ('&embed=false', false), ('&embed=true', true)]) {
        final uri = Uri.parse('/?sample_id=material.ListTile.2&run=true$embedQuery');
        final request = ProjectRequest.fromUri(uri);
        expect(request.isEmbedMode, embedded, reason: uri.toString());
        expect(ProjectRequest.isEmbedUri(uri), embedded, reason: uri.toString());
        expect(request.sdk, isNull);
        expect(request.isLegacyEmbedMode, isTrue);
        expect(request.autoRun, isTrue);
      }
    });

    test('uses legacy defaults and preserves normal preview autorun', () {
      for (final query in [
        '?sample_id=material.AppBar.1',
        '?sample_id=material.AppBar.1&run=false',
        '?sample_id=material.AppBar.1&run=anything',
      ]) {
        final request = ProjectRequest.fromUri(Uri.parse(query));
        expect(request.autoRun, isFalse, reason: query);
        expect(request.initialSplitRatio, 0.7, reason: query);
      }
      expect(ProjectRequest.fromUri(Uri.parse('?sample=counter')).autoRun, isTrue);
      expect(ProjectRequest.fromUri(Uri.parse('?sample=counter&embed=true')).isEmbedMode, isTrue);
    });

    test('clamps legacy split percentages and defaults invalid values', () {
      for (final (value, expected) in [('4', 0.05), ('96', 0.95), ('invalid', 0.7)]) {
        final request = ProjectRequest.fromUri(Uri.parse('?sample_id=sample&split=$value'));
        expect(request.initialSplitRatio, expected);
      }
    });

    for (final query in [
      '?gist=a&id=a',
      '?gist=a&id=b',
      '?url=a&package=b',
      '?sample=a&gist=b',
      '?sample=a&sample_id=b',
      '?sample_id=',
      '?version=1.0.0',
      '?sdk=other',
      '?sdk=dart:',
      '?sdk=dart:1:2',
      '?mode=other',
      '?sample=',
      '?root=a&root=b',
    ]) {
      test('rejects $query', () => expect(() => ProjectRequest.fromUri(Uri.parse(query)), throwsFormatException));
    }
    for (final query in ['?file=../escape.dart', '?root=/absolute', '?entrypoint=../main.dart', '?file=']) {
      test(
        'rejects unsafe path $query',
        () => expect(() => ProjectRequest.fromUri(Uri.parse(query)), throwsArgumentError),
      );
    }
  });

  group('InitialProjectState', () {
    test('documentation samples use normal SDK inference and respect explicit overrides', () {
      for (final (importsFlutter, sdkQuery, flutterSdk) in [
        (true, '', true),
        (false, '', false),
        (true, '&sdk=dart', false),
      ]) {
        final state = resolve('?sample_id=material.ListTile.2$sdkQuery', {
          'lib/main.dart': '${importsFlutter ? "import 'package:flutter/material.dart';" : ""} void main() {}',
        });
        expect(state.sdk.isFlutter, flutterSdk);
        expect(state.mode, flutterSdk ? RunMode.flutter : RunMode.console);
        expect(state.hasPubspec, isTrue);
      }
    });

    group('generated Gist pubspec', () {
      const available = [
        SdkInfo(id: 'dart', name: 'Dart', path: 'dart/', dartVersion: '3.13.3'),
        SdkInfo(id: 'dart-dev', name: 'Dart dev', path: 'dart-dev/', dartVersion: '3.15.0-edge'),
        SdkInfo(
          id: 'flutter',
          name: 'Flutter',
          path: 'flutter/',
          dartVersion: '3.14.0 (build 3.14.0-201.0.dev)',
          flutterVersion: '3.48.0',
        ),
      ];

      for (final (query, importsFlutter, sdkIndex, constraint) in [
        ('?gist=abc', false, 0, '^3.13.3-0'),
        ('?gist=abc', true, 2, '^3.14.0-0'),
        ('?gist=abc&sdk=flutter:3.48.0', false, 2, '^3.14.0-0'),
        ('?gist=abc&sdk=dart', true, 0, '^3.13.3-0'),
        ('?gist=abc&sdk=dart:3.15.0-edge', false, 1, '^3.15.0-0'),
      ]) {
        test('uses selected SDK for $query, Flutter import=$importsFlutter', () {
          final project = contents({
            'lib/main.dart': '${importsFlutter ? "import 'package:flutter/material.dart';" : ""} void main() {}',
          });
          final state = InitialProjectState.resolve(ProjectRequest.fromUri(Uri.parse(query)), project, available);
          expect(state.sdk, available[sdkIndex]);
          expect(state.hasPubspec, isTrue);
          expect(state.mode, available[sdkIndex].isFlutter ? RunMode.flutter : RunMode.console);
          expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: $constraint'));
        });
      }

      test('preserves existing pubspecs byte for byte', () {
        for (final pubspec in ['name: existing', 'name: existing\nenvironment:\n  sdk: ^3.10.0\n']) {
          final project = contents({'pubspec.yaml': pubspec, 'lib/main.dart': 'void main() {}'});
          InitialProjectState.resolve(ProjectRequest.fromUri(Uri.parse('?gist=abc')), project, available);
          expect(utf8.decode(project.readFile('pubspec.yaml')!), pubspec);
        }
      });

      test('opens the generated pubspec when explicitly requested', () {
        final project = contents({'lib/main.dart': 'void main() {}'});
        final state = InitialProjectState.resolve(
          ProjectRequest.fromUri(Uri.parse('?gist=abc&file=pubspec.yaml')),
          project,
          available,
        );
        expect(state.files, ['pubspec.yaml']);
        expect(state.entrypoint, 'lib/main.dart');
        expect(state.hasPubspec, isTrue);
        expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: ^3.13.3-0'));
      });

      test('uses the nested package SDK when an entrypoint selects that package', () {
        final project = contents({
          'example/pubspec.yaml': 'name: example\ndependencies:\n  flutter:\n    sdk: flutter',
          'example/lib/main.dart': 'void main() {}',
        });
        final state = InitialProjectState.resolve(
          ProjectRequest.fromUri(Uri.parse('?gist=abc&entrypoint=example/lib/main.dart')),
          project,
          available,
        );
        expect(state.root, 'example');
        expect(state.sdk, available.last);
        expect(utf8.decode(project.readFile('pubspec.yaml')!), contains('sdk: ^3.14.0-0'));
        expect(
          utf8.decode(project.readFile('example/pubspec.yaml')!),
          'name: example\ndependencies:\n  flutter:\n    sdk: flutter',
        );
      });

      test('fails for an unavailable SDK without generating a pubspec', () {
        final project = contents({'lib/main.dart': 'void main() {}'});
        expect(
          () => InitialProjectState.resolve(
            ProjectRequest.fromUri(Uri.parse('?gist=abc&sdk=dart:1.0.0')),
            project,
            available,
          ),
          throwsFormatException,
        );
        expect(project.containsFile('pubspec.yaml'), isFalse);
      });
    });

    test('Flutter detection handles typed YAML mappings with heterogeneous values', () {
      const pubspec = <Object?, Object?>{
        42: 'non-string key',
        'environment': ['flutter'],
        'dependencies': {
          'plain': 'flutter',
          'missing': null,
          'list': ['flutter'],
          'other': {'sdk': 'dart'},
        },
      };
      expect(pubspecUsesFlutter(pubspec), isFalse);
      expect(
        pubspecUsesFlutter({
          ...pubspec,
          'dev_dependencies': {
            'flutter_test': {'sdk': 'flutter'},
          },
        }),
        isTrue,
      );
      expect(
        resolve('', {
          'pubspec.yaml': '42: value\nenvironment: [flutter]\ndependencies:\n  plain: flutter\n  missing: null',
        }).sdk,
        sdks.first,
      );
      expect(() => resolve('', {'pubspec.yaml': '- not a mapping'}), throwsFormatException);
    });
    test('normalizes explicit workspace roots and rejects unsafe paths', () {
      for (final root in ['', '.', './', 'nested/..']) {
        expect(resolve('?root=$root', {}).root, '');
      }
      for (final path in ['/outside', '../outside']) {
        expect(() => ProjectLoader.normalizePath(path), throwsArgumentError);
      }
    });
    test('defaults to README and detects main separately', () {
      final state = resolve('', {
        'README.md': '# Project',
        'pubspec.yaml': 'name: demo',
        'lib/main.dart': 'void main() {}',
      });
      expect(state.files, ['README.md']);
      expect(state.root, '');
      expect(state.entrypoint, 'lib/main.dart');
      expect(state.sdk, sdks.first);
      expect(state.mode, RunMode.console);
      expect(state.hasPubspec, isTrue);
    });
    test('default README and main use the explicit root', () {
      final state = resolve('?root=example', {
        'README.md': '# Package',
        'pubspec.yaml': 'name: demo',
        'lib/main.dart': 'void main() {}',
        'example/README.md': '# Example',
        'example/pubspec.yaml': 'name: demo_example',
        'example/lib/main.dart': 'void main() {}',
      });
      expect(state.root, 'example');
      expect(state.files, ['example/README.md']);
      expect(state.entrypoint, 'example/lib/main.dart');
    });
    for (final hasMain in [true, false]) {
      test('missing root README never falls back to the source README, hasMain=$hasMain', () {
        final state = resolve('?root=example', {
          'README.md': '# Package',
          'lib/main.dart': 'void main() {}',
          'example/pubspec.yaml': 'name: demo_example',
          if (hasMain) 'example/lib/main.dart': 'void main() {}',
        });
        expect(state.files, hasMain ? ['example/lib/main.dart'] : isEmpty);
        expect(state.entrypoint, hasMain ? 'example/lib/main.dart' : isNull);
      });
    }
    test('source README does not affect root inference from an explicit entrypoint', () {
      final state = resolve('?entrypoint=example/tool/start.dart', {
        'README.md': '# Package',
        'pubspec.yaml': 'name: demo',
        'example/README.md': '# Example',
        'example/pubspec.yaml': 'name: demo_example',
        'example/tool/start.dart': 'void main() {}',
      });
      expect(state.root, 'example');
      expect(state.files, ['example/README.md']);
      expect(state.entrypoint, 'example/tool/start.dart');
    });
    test('explicit files and entrypoint stay source-relative with a nested root', () {
      final state = resolve('?root=example&file=README.md&entrypoint=lib/main.dart', {
        'README.md': '# Package',
        'lib/main.dart': 'void main() {}',
        'example/README.md': '# Example',
        'example/lib/main.dart': 'void main() {}',
      });
      expect(state.root, 'example');
      expect(state.files, ['README.md']);
      expect(state.entrypoint, 'lib/main.dart');
    });
    for (final example in [
      (query: '', entrypoint: 'lib/main.dart'),
      (query: '?root=example', entrypoint: 'example/lib/main.dart'),
      (query: '?entrypoint=tool/start.dart', entrypoint: 'tool/start.dart'),
    ]) {
      test('opens the resolved entrypoint without README for ${example.query}', () {
        final state = resolve(example.query, {example.entrypoint: 'void main() {}'});
        expect(state.files, [example.entrypoint]);
        expect(state.entrypoint, example.entrypoint);
        expect(state.request.files, isEmpty);
      });
    }
    test('does not replace explicit tabs with the main fallback', () {
      final state = resolve('?file=notes.txt', {
        'notes.txt': 'Notes',
        'lib/main.dart': 'void main() {}',
      });
      expect(state.files, ['notes.txt']);
      expect(state.entrypoint, 'lib/main.dart');
      expect(() => resolve('?file=README.md', {'lib/main.dart': 'void main() {}'}), throwsFormatException);
    });
    test('opens the mapped Gist entrypoint when README is absent', () {
      final state = InitialProjectState.resolve(
        ProjectRequest.fromUri(Uri.parse('?gist=abc&entrypoint=main.dart')),
        contents({'lib/main.dart': 'void main() {}'}, mapping: {'main.dart': 'lib/main.dart'}),
        sdks,
      );
      expect(state.files, ['lib/main.dart']);
    });
    test('infers a nested root from an explicit entrypoint without README', () {
      final state = resolve('?entrypoint=example/tool/start.dart', {
        'example/pubspec.yaml': 'name: example',
        'example/tool/start.dart': 'void main() {}',
      });
      expect(state.files, ['example/tool/start.dart']);
      expect(state.root, 'example');
      expect(state.entrypoint, 'example/tool/start.dart');
      expect(state.hasPubspec, isTrue);
    });
    for (final root in ['', 'example']) {
      final prefix = root.isEmpty ? '' : '$root/';
      for (final libMain in [null, '// void main() {}', 'void main() {}']) {
        test('uses root main after lib main, root=$root, libMain=$libMain', () {
          final state = resolve('?root=$root', {
            '${prefix}lib/main.dart': ?libMain,
            '${prefix}main.dart': 'void main() {}',
            if (root.isNotEmpty) 'main.dart': 'void main() {}',
          });
          final expected = libMain == 'void main() {}' ? '${prefix}lib/main.dart' : '${prefix}main.dart';
          expect(state.entrypoint, expected);
          expect(state.files, [expected]);
        });
      }
    }
    test('leaves tabs empty when neither main candidate is an entrypoint', () {
      final state = resolve('', {
        'lib/main.dart': '// void main() {}',
        'main.dart': 'class App { void main() {} }',
      });
      expect(state.files, isEmpty);
      expect(state.entrypoint, isNull);
    });
    test('uses deepest shared pubspec for all files and explicit main', () {
      final files = {
        'pubspec.yaml': 'name: root',
        'example/pubspec.yaml': 'name: example',
        'example/a.dart': 'void main() {}',
        'example/lib/b.dart': 'void main() {}',
        'bin/app.dart': 'void main() {}',
      };
      final nested = resolve('?file=example/a.dart&file=example/lib/b.dart', files);
      expect(nested.root, 'example');
      expect(nested.entrypoint, 'example/a.dart');
      final shared = resolve('?file=example/a.dart&entrypoint=bin/app.dart', files);
      expect(shared.root, '');
      expect(shared.entrypoint, 'bin/app.dart');
    });
    test('explicit root keeps source-relative file paths and roots the main fallback', () {
      final state = resolve('?root=example&file=example/README.md', {
        'example/README.md': '# Example',
        'example/pubspec.yaml': 'name: example',
        'example/lib/main.dart': 'void main() {}',
        'lib/main.dart': 'void main() {}',
      });
      expect(state.files, ['example/README.md']);
      expect(state.root, 'example');
      expect(state.entrypoint, 'example/lib/main.dart');
    });
    test('deduplicates tabs while preserving first occurrence order', () {
      final state = resolve('?file=b.dart&file=a.dart&file=b.dart', {
        'a.dart': 'void main() {}',
        'b.dart': 'void main() {}',
      });
      expect(state.files, ['b.dart', 'a.dart']);
      expect(state.entrypoint, 'b.dart');
    });
    test('rejects missing explicit files, root and entrypoint', () {
      for (final query in ['?file=missing.dart', '?entrypoint=missing.dart', '?root=missing']) {
        expect(() => resolve(query, {}), throwsFormatException);
      }
    });
    for (final pubspec in [
      'environment:\n  flutter: ">=3.0.0"',
      'dependencies:\n  flutter:\n    sdk: flutter',
      'dev_dependencies:\n  flutter_test:\n    sdk: flutter',
      'flutter: {}',
    ]) {
      test('detects Flutter from $pubspec', () {
        final state = resolve('', {'pubspec.yaml': pubspec, 'lib/main.dart': 'void main() {}'});
        expect(state.sdk, sdks.last);
        expect(state.mode, RunMode.flutter);
      });
    }
    test('SDK and mode overrides win; unavailable versions fail', () {
      final files = {'pubspec.yaml': 'flutter: {}', 'lib/main.dart': 'void main() {}'};
      expect(resolve('?sdk=dart:3.12.0', files).mode, RunMode.console);
      expect(resolve('?sdk=flutter:3.44.0&mode=console', files).mode, RunMode.console);
      expect(() => resolve('?sdk=dart:1.0.0', files), throwsFormatException);
      expect(() => resolve('?sdk=flutter:3.12.0', files), throwsFormatException);
      expect(() => resolve('?sdk=dart&mode=flutter', files), throwsFormatException);
    });
    for (final directory in ['bin', 'test', 'tool', 'lib', 'web', 'binary']) {
      test('infers mode relative to nearest pubspec for $directory', () {
        final state = resolve('?sdk=flutter&file=example/$directory/main.dart', {
          'pubspec.yaml': 'name: root',
          'example/pubspec.yaml': 'name: example',
          'example/$directory/main.dart': 'void main() {}',
        });
        expect(state.mode, ['bin', 'test', 'tool'].contains(directory) ? RunMode.console : RunMode.flutter);
      });
    }
    test('uses original Gist query paths after moving files to lib', () {
      final state = InitialProjectState.resolve(
        ProjectRequest.fromUri(Uri.parse('?gist=abc&file=main.dart&entrypoint=main.dart')),
        contents(
          {'pubspec.yaml': 'name: gist', 'lib/main.dart': 'void main() {}'},
          mapping: {'main.dart': 'lib/main.dart'},
        ),
        sdks,
      );
      expect(state.request.files, ['main.dart']);
      expect(state.files, ['lib/main.dart']);
      expect(state.entrypoint, 'lib/main.dart');
      expect(state.root, '');
    });
    test('resolved metadata stays immutable after loaded files change', () {
      final project = contents({'lib/main.dart': 'void main() {}'});
      final state = InitialProjectState.resolve(ProjectRequest.example(), project, sdks);
      project.writeFile('lib/main.dart', Uint8List(0));
      project.writeFile('pubspec.yaml', Uint8List.fromList('flutter: {}'.codeUnits));
      expect(state.files, ['lib/main.dart']);
      expect(state.entrypoint, 'lib/main.dart');
      expect(state.root, '');
      expect(state.sdk.isFlutter, isFalse);
      expect(state.mode, RunMode.console);
      expect(state.hasPubspec, isFalse);
      expect(() => state.files.add('new.dart'), throwsUnsupportedError);
    });
  });

  test('main detection handles functions, not comments, strings, getters or methods', () {
    for (final source in ['void main() {}', 'main() => 42;', 'Future<void> main(List<String> args) async {}']) {
      expect(dartSourceHasMain(source), isTrue, reason: source);
    }
    for (final source in [
      '// void main() {}',
      '/* void main() {} */',
      'const text = "void main() {}";',
      'class Demo { void main() {} }',
      'void other() { void main() {} }',
      'int get main => 1;',
    ]) {
      expect(dartSourceHasMain(source), isFalse, reason: source);
    }
  });
}
