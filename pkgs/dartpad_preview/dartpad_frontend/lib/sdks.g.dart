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
    dartVersion: '3.14.0 (build 3.14.0-315.1.beta)',
    flutterVersion: '3.49.0-1.0.pre-444',
  ),
  SdkInfo(
    id: 'dart',
    name: 'Dart',
    path: 'dartpad/dart/',
    dartVersion: '3.15.0-edge.00ca160f917cb531a91fe61ca5464fca2ad11db6',
  ),
];

final defaultSdk = availableSdks.firstWhere(
  (sdk) => sdk.id == defaultSdkId,
  orElse: () => availableSdks.first,
);
