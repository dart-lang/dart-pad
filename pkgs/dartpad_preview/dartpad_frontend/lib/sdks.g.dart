// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
//
// Generated file. Do not edit directly.
// Run `dart tool/setup_sdk_assets.dart` to regenerate.

import 'features/shared/sdk_info.dart';

const defaultSdkId = 'flutter';

const availableSdks = <SdkInfo>[
  SdkInfo(
    id: 'flutter',
    name: 'Flutter',
    path: 'dartpad/flutter/',
    channel: 'stable',
    dartVersion: '3.14.0',
    flutterVersion: '3.50.1',
  ),
  SdkInfo(
    id: 'dart',
    name: 'Dart',
    path: 'dartpad/dart/',
    channel: 'stable',
    dartVersion: '3.14.1',
  ),
];

final defaultSdk = availableSdks.firstWhere(
  (sdk) => sdk.id == defaultSdkId,
  orElse: () => availableSdks.first,
);
