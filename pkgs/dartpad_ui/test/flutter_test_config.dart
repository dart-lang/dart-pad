// Copyright (c) 2025, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test configuration for each test library in this directory.
///
/// See https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  // Set golden file comparator to use a custom tolerance.
  goldenFileComparator = _GoldenDiffComparator();

  await testMain();
}

/// Customization of tolerance for golden file comparison.
///
/// See https://github.com/flutter/flutter/pull/77014#issuecomment-1048896776
class _GoldenDiffComparator extends LocalFileComparator {
  _GoldenDiffComparator() : super(Uri.parse('.'));

  static const _tolerance = 0.015; // 1.5% of difference is ok.

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final ComparisonResult result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );

    if (!result.passed && result.diffPercent > _tolerance) {
      final String error = await generateFailureOutput(result, golden, basedir);
      throw FlutterError(error);
    }
    if (!result.passed) {
      debugPrint(
        'A tolerable difference of ${result.diffPercent * 100}% was found when '
        'comparing $golden, that is acceptable as it is '
        'less than the tolerance of ${_tolerance * 100}%.',
      );
    }
    return result.passed || result.diffPercent <= _tolerance;
  }
}
