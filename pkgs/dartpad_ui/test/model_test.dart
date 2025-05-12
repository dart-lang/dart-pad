// Copyright (c) 2024, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/server.dart';
import 'package:dartpad_shared/model.dart';
import 'package:dartpad_ui/model.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() async {
    await TestServerRunner().maybeStart();
  });

  group('Channel', () {
    test('master is aliased', () {
      final value = Channel.forName('master');
      expect(value?.name, 'main');
    });

    test('supported channels', () {
      final result = Channel.valuesWithoutLocalhost.map((c) => c.name).toList();
      expect(result, unorderedMatches(['main', 'beta', 'stable']));
    });
  });

  group('AppServices', () {
    test('populateVersions', () async {
      final appModel = AppModel();
      final appServices = AppServices(appModel, Channel.localhost);

      expect(appModel.runtimeVersions.value, null);
      await appServices.populateVersions();
      expect(appModel.runtimeVersions.value, isA<VersionResponse>());
    });
  });

  group('GenAiManager', () {
    test('defaults are empty', () {});
  });
}

void verifyDefaults(GenAiManager manager) {
  expect(GenAiManager().activity.value, null);
}
