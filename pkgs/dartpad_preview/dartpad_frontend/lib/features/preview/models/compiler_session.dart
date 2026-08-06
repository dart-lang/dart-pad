// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad/dartpad.dart';

/// Represents a hot-reload compilation session.
abstract interface class CompilerSession {
  Future<({String? code, List<String> compiledLibraryUris, String? log})> compile();
  Future<void> close();
}

/// A wrapper around [HotReloadCompiler] implementing [CompilerSession].
class RealCompilerSession implements CompilerSession {
  RealCompilerSession(this._compiler);

  final HotReloadCompiler _compiler;

  @override
  Future<({String? code, List<String> compiledLibraryUris, String? log})> compile() => _compiler.compile();

  @override
  Future<void> close() => _compiler.close();
}
