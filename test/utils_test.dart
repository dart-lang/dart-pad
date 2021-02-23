library utils.tests;

import 'package:dart_services/src/utils.dart';
import 'package:expected_output/expected_output.dart';
import 'package:test/test.dart';

void main() {
  group('utils.stripFilePaths', () {
    for (final dataCase in dataCasesUnder(library: #utils.tests)) {
      test(dataCase.testDescription, () {
        final actualOutput = stripFilePaths(dataCase.input);
        expect(actualOutput, equals(dataCase.expectedOutput));
      });
    }
  });
}
