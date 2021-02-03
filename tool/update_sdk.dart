// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:dart_services/src/sdk_manager.dart';

// This tool is used to manually update the `flutter-sdk/` Flutter SDK to match
// the current configuration information in the `flutter-sdk-version.yaml` file.

void main(List<String> args) async {
  final info = DownloadingSdkManager.getSdkConfigInfo();
  print('configuration: $info\n');

  final DownloadingSdkManager sdkManager = DownloadingSdkManager();
  final DownloadedFlutterSdk sdk = await sdkManager.createFromConfigFile();

  print('\nSDK setup complete (${sdk.flutterSdkPath}).');
}
