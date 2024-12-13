// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_ui/local_storage.dart';
import 'package:dartpad_ui/model.dart';
import 'package:dartpad_ui/samples.g.dart';
import 'package:dartpad_ui/utils.dart';

import 'package:test/test.dart';

String getFallback() =>
  LocalStorage.instance.getUserCode() ?? Samples.defaultSnippet();

Never throwingFallback() => throw StateError('DartPad tried to load the fallback');

void main() {
  const channel = Channel.stable;
  group('Autosave:', () {
    test('empty content is treated as null', () {
      expect(''.nullIfEmpty, isNull);

      LocalStorage.instance.saveUserCode('non-empty');
      expect(LocalStorage.instance.getUserCode(), isNotNull);

      LocalStorage.instance.saveUserCode('');
      expect(LocalStorage.instance.getUserCode(), isNull);
    });

    test('null content means sample snippet is shown', () async {
      final model = AppModel();
      final services = AppServices(model, channel);
      LocalStorage.instance.saveUserCode('');
      expect(LocalStorage.instance.getUserCode(), isNull);

      await services.performInitialLoad(
        getFallback: getFallback,
      );
      expect(model.sourceCodeController.text, equals(Samples.defaultSnippet()));
    });

    test('non-null content is shown', () async {
      const sample = 'Hello, World!';
      final model = AppModel();
      final services = AppServices(model, channel);
      LocalStorage.instance.saveUserCode(sample);
      expect(LocalStorage.instance.getUserCode(), equals(sample));

      await services.performInitialLoad(
        getFallback: getFallback,
      );
      expect(model.sourceCodeController.text, equals(sample));
    });

    group('content is not shown with', () {
      const sample = 'Hello, World!';
      LocalStorage.instance.saveUserCode(sample);
      // Not testing flutterSampleId to avoid breaking when the Flutter docs change

      test('Gist', () async {
        final model = AppModel();
        final services = AppServices(model, channel);
        expect(LocalStorage.instance.getUserCode(), equals(sample));

        // From gists_tests.dart
        const gistId = 'd3bd83918d21b6d5f778bdc69c3d36d6';
        await services.performInitialLoad(
          getFallback: throwingFallback,
          gistId: gistId,
        );
        expect(model.sourceCodeController.text, isNot(equals(sample)));
      });

      test('sample', () async {
        final model = AppModel();
        final services = AppServices(model, channel);
        expect(LocalStorage.instance.getUserCode(), equals(sample));

        // From samples_test.dart
        const sampleId = 'dart';
        await services.performInitialLoad(
          getFallback: throwingFallback,
          sampleId: sampleId,
        );
        expect(model.sourceCodeController.text, isNot(equals(sample)));
      });
    });
  });
}
