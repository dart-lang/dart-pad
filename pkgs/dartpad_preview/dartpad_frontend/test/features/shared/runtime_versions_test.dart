// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dartpad_frontend/features/shared/runtime_versions.dart';
import 'package:test/test.dart';

void main() {
  test('reads runtime versions from an asset manifest', () {
    final versions = RuntimeVersions.fromManifest({
      'dartVersion': '3.14.0',
      'flutterVersion': '3.47.0',
    });

    expect(versions?.dart, '3.14.0');
    expect(versions?.flutter, '3.47.0');
  });

  test('rejects manifests without string version fields', () {
    expect(RuntimeVersions.fromManifest({'dartVersion': 3}), isNull);
    expect(RuntimeVersions.fromManifest(null), isNull);
  });
}
