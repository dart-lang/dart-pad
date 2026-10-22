// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/preview/models/run_mode.dart';
import 'package:dartpad_frontend/features/startup/query_parameters.dart';
import 'package:test/test.dart';

QueryParameters parse(String query) => QueryParameters.fromUri(Uri.parse(query));

void expectSource(String query, Matcher matcher) => expect(parse(query).source, matcher, reason: query);

void expectInvalid(String query) => expect(() => parse(query), throwsFormatException, reason: query);

void main() {
  group('QueryParameters sources', () {
    test('parses each source kind', () {
      expectSource('', isNull);
      expectSource(
        '?url=https://example.com/a.tar',
        isA<UrlSourceSelection>().having((source) => source.url, 'url', 'https://example.com/a.tar'),
      );
      expectSource(
        '?package=foo&version=1.2.3',
        isA<PackageSourceSelection>()
            .having((source) => source.package, 'package', 'foo')
            .having((source) => source.version, 'version', '1.2.3'),
      );
      expectSource(
        '?sample_id=material.AppBar.1&channel=main',
        isA<ApiDocsSourceSelection>()
            .having((source) => source.sampleId, 'sampleId', 'material.AppBar.1')
            .having((source) => source.channel, 'channel', FlutterApiChannel.main),
      );
      expectSource(
        '?sample=counter',
        isA<SampleSourceSelection>().having((source) => source.sampleId, 'sampleId', 'counter'),
      );
    });

    test('accepts gist and id as the same source', () {
      for (final key in ['gist', 'id']) {
        expectSource('?$key=abc', isA<GistSourceSelection>().having((source) => source.gistId, 'gistId', 'abc'));
      }
    });

    test('rejects more than one source', () {
      for (final query in ['?url=a&package=b', '?sample=a&sample_id=b', '?gist=a&sample=b']) {
        expectInvalid(query);
      }
    });

    test('rejects gist and id together', () {
      for (final query in ['?gist=a&id=b', '?gist=a&id=a']) {
        expectInvalid(query);
      }
    });

    test('rejects a version without a package', () => expectInvalid('?version=1.0.0'));

    test('rejects empty or repeated source values', () {
      for (final query in ['?url=', '?package=', '?gist=', '?sample=', '?sample_id=', '?sample=a&sample=b']) {
        expectInvalid(query);
      }
    });

    test('rejects retired parameters', () {
      for (final key in ['archive', 'path', 'main']) {
        expectInvalid('?$key=a');
      }
    });
  });

  group('QueryParameters project', () {
    test('parses root, entrypoint, and files in URL order', () {
      final project = parse(
        '?root=example&entrypoint=example/bin/main.dart&file=README.md&file=lib/main.dart&file=README.md',
      ).project;

      expect(project.root, 'example');
      expect(project.entrypoint, 'example/bin/main.dart');
      expect(project.files, ['README.md', 'lib/main.dart', 'README.md']);
    });

    test('accepts an empty root as the source root', () => expect(parse('?root=').project.root, isEmpty));

    test('parses sdk kind with an optional version', () {
      final dart = parse('?sdk=dart').project;
      expect(dart.sdk, SdkKind.dart);
      expect(dart.sdkVersion, isNull);

      final flutter = parse('?sdk=flutter:3.44.0').project;
      expect(flutter.sdk, SdkKind.flutter);
      expect(flutter.sdkVersion, '3.44.0');
    });

    test('parses run mode', () {
      expect(parse('?mode=flutter').project.mode, RunMode.flutter);
      expect(parse('?mode=console').project.mode, RunMode.console);
    });

    test('rejects invalid project values', () {
      for (final query in [
        '?root=a&root=b',
        '?entrypoint=',
        '?sdk=other',
        '?sdk=dart:',
        '?sdk=dart:1:2',
        '?mode=other',
      ]) {
        expectInvalid(query);
      }
    });

    test('rejects unsafe paths', () {
      for (final query in ['?file=../escape.dart', '?root=/absolute', '?entrypoint=../main.dart', '?file=']) {
        expect(() => parse(query), throwsArgumentError, reason: query);
      }
    });
  });

  group('QueryParameters presentation', () {
    test('parses embed only when true', () {
      expect(parse('?embed=true').appearance.embed, isTrue);
      expect(parse('?embed=false').appearance.embed, isFalse);
      expect(parse('').appearance.embed, isFalse);
    });

    test('parses theme', () {
      expect(parse('?theme=dark').appearance.theme, UITheme.dark);
      expect(parse('?theme=light').appearance.theme, UITheme.light);
    });

    test('clamps split and defaults invalid values', () {
      for (final (query, expected) in [
        ('?split=60', 60),
        ('?split=4', 5),
        ('?split=96', 95),
        ('?split=abc', 70),
        ('', 70),
      ]) {
        expect(parse(query).appearance.splitPercent, expected, reason: query);
      }
    });

    test('ignores invalid presentation values', () {
      for (final query in ['?theme=neon', '?split=abc', '?embed=yes', '?theme=dark&theme=light']) {
        expect(() => parse(query), returnsNormally, reason: query);
      }
    });
  });

  group('QueryParameters session', () {
    test('parses non-negative session ids only', () {
      expect(parse('?s=5').session?.value, 5);
      for (final query in ['', '?s=-1', '?s=abc']) {
        expect(parse(query).session, isNull, reason: query);
      }
    });
  });

  test('uses defaults for an empty query', () {
    final parameters = parse('');

    expect(parameters.source, isNull);
    expect(parameters.raw, isEmpty);
    expect(parameters.project.root, isNull);
    expect(parameters.project.entrypoint, isNull);
    expect(parameters.project.files, isEmpty);
    expect(parameters.appearance.embed, isFalse);
    expect(parameters.appearance.theme, isNull);
    expect(parameters.appearance.splitPercent, PresentationParameters.defaultSplitPercent);
    expect(parameters.session, isNull);
  });
}
