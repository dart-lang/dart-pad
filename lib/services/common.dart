// Copyright (c) 2014, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

library dart_pad.common;

/// The environment variable name which specifies the URL of the pre-null safety
/// back-end server.
///
/// This typically is specified in `dart2js_args` passed via a build_runner
/// option. The `grind build` task specifies this option.
const preNullSafetyServerUrlEnvironmentVar = 'PRE_NULL_SAFETY_SERVER_URL';

/// The URL of the pre-null safety back-end server.
const preNullSafetyServerUrl =
    String.fromEnvironment(preNullSafetyServerUrlEnvironmentVar);

/// The environment variable name which specifies the URL of the null safety
/// back-end server.
///
/// This typically is specified in `dart2js_args` passed via a build_runner
/// option. The `grind build` task specifies this option.
const nullSafetyServerUrlEnvironmentVar = 'NULL_SAFETY_SERVER_URL';

/// The URL of the null safety back-end server.
const nullSafetyServerUrl =
    String.fromEnvironment(nullSafetyServerUrlEnvironmentVar);

// Alternate versions for development purposes
// const serverUrl = 'https://old.api.dartpad.dev/';
// const serverUrl = 'https://stable.api.dartpad.dev/';
// const serverUrl = 'https://beta.api.dartpad.dev/';
// const serverUrl = 'https://dev.api.dartpad.dev/';

const Duration serviceCallTimeout = Duration(seconds: 10);
const Duration longServiceCallTimeout = Duration(seconds: 60);

class Lines {
  final _starts = <int>[];

  Lines(String source) {
    var units = source.codeUnits;
    var nextIsEol = true;
    for (var i = 0; i < units.length; i++) {
      if (nextIsEol) {
        nextIsEol = false;
        _starts.add(i);
      }
      if (units[i] == 10) nextIsEol = true;
    }
  }

  /// Return the 0-based line number.
  int getLineForOffset(int offset) {
    if (_starts.isEmpty) return 0;
    for (var i = 1; i < _starts.length; i++) {
      if (offset < _starts[i]) return i - 1;
    }
    return _starts.length - 1;
  }

  int offsetForLine(int line) {
    assert(line >= 0);
    if (_starts.isEmpty) return 0;
    if (line >= _starts.length) line = _starts.length - 1;
    return _starts[line];
  }
}
