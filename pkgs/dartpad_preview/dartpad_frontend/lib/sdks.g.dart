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
    id: 'flutter-beta',
    name: 'Flutter',
    path: 'dartpad/flutter-beta/',
    channel: 'beta',
    dartVersion: '3.15.0 (build 3.15.0-118.1.beta)',
    flutterVersion: '3.51.0-0.2.pre',
  ),
  SdkInfo(
    id: 'flutter-main',
    name: 'Flutter',
    path: 'dartpad/flutter-main/',
    channel: 'main',
    dartVersion: '3.15.0 (build 3.15.0-168.0.dev)',
    flutterVersion: '3.51.0-1.0.pre-255',
  ),
  SdkInfo(
    id: 'dart',
    name: 'Dart',
    path: 'dartpad/dart/',
    channel: 'stable',
    dartVersion: '3.14.1',
  ),
  SdkInfo(
    id: 'dart-beta',
    name: 'Dart',
    path: 'dartpad/dart-beta/',
    channel: 'beta',
    dartVersion: '3.15.0-118.1.beta',
  ),
  SdkInfo(
    id: 'dart-main',
    name: 'Dart',
    path: 'dartpad/dart-main/',
    channel: 'main',
    dartVersion: '3.15.0-edge.8e8f29e404ee5451bda87d015fb45775c71355f2',
  ),
];

final defaultSdk = availableSdks.firstWhere(
  (sdk) => sdk.id == defaultSdkId,
  orElse: () => availableSdks.first,
);
