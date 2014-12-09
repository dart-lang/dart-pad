
library mock_analysis;

import 'dart:async';

import '../analysis.dart';
import '../dependencies.dart';
import '../modules.dart';

class MockAnalysisModule extends Module {
  MockAnalysisModule();

  Future init() {
    //Dependencies.instance[CompilerService] = new MockCompilerService();
    return new Future.value();
  }
}
