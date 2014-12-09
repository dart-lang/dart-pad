
library mock_compiler;

import 'dart:async';

import '../compiler.dart';
import '../dependencies.dart';
import '../modules.dart';

class MockCompilerModule extends Module {
  MockCompilerModule();

  Future init() {
    Dependencies.instance[CompilerService] = new MockCompilerService();
    return new Future.value();
  }
}

class MockCompilerService extends CompilerService {
  Future<CompilerResult> compile(String source) {
    // TODO: have the 'compiled' result do something.
    return new Future.value(new CompilerResult(''));
  }
}
