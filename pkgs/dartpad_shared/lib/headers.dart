// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const _loggingOnHeaderName = 'X-Enable-Logging';

/// A class that represents the custom request headers for DartPad.
///
/// Standard serialization is not used, because the header name should have
/// prefix 'X-'.
class DartPadRequestHeaders {
  static final instance = DartPadRequestHeaders();

  /// The default value is true.
  ///
  /// The value is set to false for clients where debug asserts are enabled.
  /// It can be set to false in constructor.
  late final bool enableLogging;

  DartPadRequestHeaders({this.enableLogging = true});

  factory DartPadRequestHeaders.fromJson(Map<String, String> json) {
    final loggingOnString = json[_loggingOnHeaderName];
    return DartPadRequestHeaders(
      enableLogging: loggingOnString == true.toString(),
    );
  }

  late final Map<String, String> encoded = () {
    return {if (!enableLogging) _loggingOnHeaderName: enableLogging.toString()};
  }();
}
