// Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library services.analyzer_server_test;

import 'package:services/src/analysis_server.dart';
import 'package:grinder/grinder.dart' as grinder;
import 'package:unittest/unittest.dart';

String sdkPath = grinder.getSdkDir().path;

String completionCode = r'''
void main() {
  int i = 0;
  i.
}
''';

void defineTests() {
  AnalysisServerWrapper analysisServer;

  group('analysis_server', () {
    setUp(() {
      analysisServer = new AnalysisServerWrapper(sdkPath);
    });

    tearDown(() {
      analysisServer.shutdown();
    });

    test('simple', () {
      //Just after i.
      return analysisServer.complete(completionCode, 32).then(
          (CompleteResponse results) {
        expect(results.replacementLength, 0);
        expect(results.replacementOffset, 32);
        expect(completionsContains(results, "abs"), true);
        expect(completionsContains(results, "codeUnitAt"), false);
      });
    });
  });
}


bool completionsContains(CompleteResponse response, String completion) =>
    response.completions.any((map) => map["completion"] == completion);

