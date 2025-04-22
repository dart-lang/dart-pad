// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test configuration for each test library in this directory.
///
/// See https://api.flutter.dev/flutter/flutter_test/flutter_test-library.html.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  goldenFileComparator = _GoldenDiffComparator();

  await testMain();
}

/// Customization of tolerance for golden file comparison.
///
/// See https://github.com/flutter/flutter/pull/77014#issuecomment-1048896776
class _GoldenDiffComparator extends LocalFileComparator {
  _GoldenDiffComparator() : super(Uri.parse('.'));

  static const _tolerance = 0.000000001;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    print('!!!!!! Comparing $golden with tolerance of ${_tolerance * 100}%.');
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
        'comparing $golden, that is less than the tolerance of ${_tolerance * 100}%.',
      );
    }
    return result.passed || result.diffPercent <= _tolerance;
  }
}
