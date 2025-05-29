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
    late GenAiManager manager;

    void checkDefaults() {
      expect(manager.activity.value, null);
      expect(manager.cuj.value, null);
      expect(manager.streamIsDone.value, true);
      expect(manager.streamBuffer.value.isEmpty, true);
      expect(manager.newCodeAttachments.length, 0);
      expect(manager.codeEditAttachments.length, 0);
    }

    void checkState(
      GenAiActivity activity,
      GenAiCuj cuj, {
      int? newAttachments,
      int? editAttachments,
    }) {
      expect(manager.activity.value, activity);
      expect(manager.cuj.value, cuj);
      expect(manager.newCodeAttachments.length, newAttachments ?? 0);
      expect(manager.codeEditAttachments.length, editAttachments ?? 0);
    }

    setUp(() {
      manager = GenAiManager();
      checkDefaults();
    });

    tearDown(() {
      manager.resetState();
      checkDefaults();
    });

    test('new code', () {
      manager.newCodeAttachments.add(
        Attachment(name: '', base64EncodedBytes: '', mimeType: ''),
      );
      manager.enterGeneratingNew();
      checkState(
        GenAiActivity.generating,
        GenAiCuj.generateCode,
        newAttachments: 1,
      );
      manager.enterAwaitingAcceptance();
      checkState(
        GenAiActivity.awaitingAcceptance,
        GenAiCuj.generateCode,
        newAttachments: 1,
      );
    });

    test('edit code', () {
      manager.codeEditAttachments.add(
        Attachment(name: '', base64EncodedBytes: '', mimeType: ''),
      );
      manager.enterGeneratingEdit();
      checkState(
        GenAiActivity.generating,
        GenAiCuj.editCode,
        editAttachments: 1,
      );
      manager.enterAwaitingAcceptance();
      checkState(
        GenAiActivity.awaitingAcceptance,
        GenAiCuj.editCode,
        editAttachments: 1,
      );
    });

    test('suggest fix code', () {
      manager.enterSuggestingFix();
      checkState(GenAiActivity.generating, GenAiCuj.suggestFix);
      manager.enterAwaitingAcceptance();
      checkState(GenAiActivity.awaitingAcceptance, GenAiCuj.suggestFix);
    });
  });
}
