// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/startup/language_server_policy.dart';
import 'package:test/test.dart';

void main() {
  for (final userAgent in [
    'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Safari/604.1',
    'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36',
    'Mozilla/5.0 (Linux; Android 15; Tablet) AppleWebKit/537.36 Chrome/130.0 Safari/537.36',
  ]) {
    test('skips LSP on mobile: $userAgent', () {
      expect(languageServerEnabledByDefault(userAgent: userAgent), isFalse);
    });
  }

  const macUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15';

  test('keeps LSP for Mac user agents, including iPads requesting desktop sites', () {
    expect(languageServerEnabledByDefault(userAgent: macUserAgent), isTrue);
  });

  test('keeps LSP on Windows', () {
    expect(
      languageServerEnabledByDefault(
        userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36',
      ),
      isTrue,
    );
  });
}
