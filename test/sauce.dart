// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

/// A small app to hand-test getting webdriver working with saucelabs.
library sauce_test;

import 'dart:io';

import 'package:webdriver/io.dart';

main(List args) async {
  if (args.length < 2) {
    print('usage: sauce <username> <accesskey>');
    exit(1);
  }

  String username = args[0];
  String accessKey = args[1];

  Map caps = Capabilities.firefox;

  caps[Capabilities.version] = "17";
  //capabilities.setCapability("platform", Platform.XP);

  String uri = 'http://${username}:${accessKey}@ondemand.saucelabs.com:80/wd/hub';
  print('Connecting to ${uri}...');

  // TODO: debug the saucelabs connection set / session creation

  // TODO: establish the session, then use `fromExistingSession`.

  WebDriver driver = await createDriver(
      uri: Uri.parse(uri),
      desired: caps);
  await driver.get("http://www.google.com/");
  print(await driver.title);
  driver.close();
}
