// Copyright (c) 2025, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

const _loggingOnHeaderName = 'X-Enable-Logging';

/// A class that represents the custom request headers for DartPad.
///
/// Standard serialization is not used, because the header name should have
/// prefix 'X-'.
class DartPadRequestHeaders {
  /// If false, the header that turns off server side logging will be passed.
  final bool enableLogging;

  DartPadRequestHeaders({required this.enableLogging});

  factory DartPadRequestHeaders.fromJson(Map<String, String> json) {
    final loggingOnString = json[_loggingOnHeaderName];
    return DartPadRequestHeaders(
      // If the header is not present, we assume logging is on.
      enableLogging: loggingOnString != false.toString(),
    );
  }

  late final Map<String, String> encoded = () {
    return {if (!enableLogging) _loggingOnHeaderName: enableLogging.toString()};
  }();
}
