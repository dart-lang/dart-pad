
/// Update the sdk in `dart-sdk/` if necessary.
import 'dart:async';

import 'package:dart_services/src/sdk_manager.dart';

Future main() async {
  DownloadingSdk sdk = new DownloadingSdk();
  await sdk.init();

  print('');
  print('Dart SDK ${sdk.version} available at ${sdk.sdkPath}');
}
