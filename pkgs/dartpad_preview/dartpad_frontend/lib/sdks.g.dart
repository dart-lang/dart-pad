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
    dartVersion: '3.14.0 (build 3.14.0-315.3.beta)',
    flutterVersion: '3.50.0-0.2.pre',
  ),
  SdkInfo(
    id: 'dart',
    name: 'Dart',
    path: 'dartpad/dart/',
    dartVersion: '3.14.0-315.3.beta',
  ),
];

final defaultSdk = availableSdks.firstWhere(
  (sdk) => sdk.id == defaultSdkId,
  orElse: () => availableSdks.first,
);
