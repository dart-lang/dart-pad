// Copyright (c) 2026, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/startup/analyzer_policy.dart';
import 'package:test/test.dart';

import '../../user_agent_fixture.dart';

void main() {
  for (final (browser, userAgent, enabled) in [
    (
      'iPhone Safari',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Mobile/15E148 Safari/604.1',
      false,
    ),
    (
      'iPad Safari',
      'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Safari/604.1',
      false,
    ),
    (
      'iPhone Chrome',
      'Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 CriOS/130.0 Mobile/15E148 Safari/604.1',
      false,
    ),
    (
      'iPad Firefox',
      'Mozilla/5.0 (iPad; CPU OS 18_0 like Mac OS X) AppleWebKit/605.1.15 FxiOS/130.0 Mobile/15E148 Safari/605.1.15',
      false,
    ),
    (
      'Android Chrome phone',
      'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36',
      false,
    ),
    (
      'Android Chrome tablet',
      'Mozilla/5.0 (Linux; Android 15; Tablet) AppleWebKit/537.36 Chrome/130.0 Safari/537.36',
      false,
    ),
    (
      'Android Firefox',
      'Mozilla/5.0 (Android 15; Mobile; rv:130.0) Gecko/130.0 Firefox/130.0',
      false,
    ),
    (
      'Android Edge',
      'Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 Chrome/130.0 Mobile Safari/537.36 EdgA/130.0',
      false,
    ),
    (
      'Mac Safari, including iPads requesting desktop sites',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/18.0 Safari/605.1.15',
      true,
    ),
    (
      'Windows Chrome',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36',
      true,
    ),
    (
      'Windows Firefox',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
      true,
    ),
    (
      'Windows Edge',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36 Edg/130.0',
      true,
    ),
    (
      'Linux Chrome',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/130.0 Safari/537.36',
      true,
    ),
  ]) {
    test('analyzer enabled=$enabled for $browser', () {
      setUserAgent(userAgent);
      expect(analyzerEnabledByDefault(), enabled);
    });
  }
}
