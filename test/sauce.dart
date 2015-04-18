

import 'dart:io';

import 'package:webdriver/webdriver.dart';

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

  WebDriver driver = await WebDriver.createDriver(
      uri: Uri.parse(uri),
      desiredCapabilities: caps);
  await driver.get("http://www.amazon.com/");
  print(await driver.title);
  driver.close();
}
