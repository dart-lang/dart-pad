// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library dartpad.web_integration;

import 'dart:io';

import 'package:unittest/unittest.dart';
import 'package:webdriver/io.dart';

import 'src/mserve.dart';
import 'src/webdriver.dart';

main(List<String> args) async {
  createDriverFactory().then((DriverFactory factory) {
    _setupTests(factory);
  }).catchError((e) {
    print(e);
    exit(1);
  });
}

/**
 * - start a web server on `build/web/`
 * - start a webdriver client (chromedriver, phantomjs, saucelabs)
 * - run the integration tests, providing the tests each their own new webdriver
 *   client and running on a fresh dartpad page
 */
_setupTests(DriverFactory factory) async {
  print('using ${factory} webdriver');

  MicroServer server = await MicroServer.start(path: 'build/web', port: 8888);
  print('serving ${server.path} from ${server.urlBase}');

  await factory.startFactory();

  var cleanup = () async {
    print('closing server');
    await server.destroy();
    return factory.stopFactory();
  };

  group('integration', () {
    int count = 0;
    WebDriver driver;

    setUp(() async {
      print('creating driver ${factory}');
      driver = await factory.createWebDriver();
    });

    tearDown(() async {
      print('closing driver ${factory}');
      await driver.quit();

      // A hack.
      count++;
      if (count == testCases.length) await cleanup();
    });

    var _defineTest = (String name, Function fn, {bool mobile: false}) {
      test(mobile ? '${name} (mobile)' : name, () async {
        await driver.get('${server.urlBase}${mobile ? 'mobile' : 'index'}.html');
        fn(driver);
      });
    };

    // Each test here should be an integration test.
    _defineTest('check title', testCheckTitle);
    _defineTest('check title exact', testCheckTitleExact);
    _defineTest('check title', testCheckTitle, mobile: true);
  });
}

testCheckTitle(WebDriver driver) async {
  String title = await driver.title;
  expect(title, startsWith('DartPad'));
}

testCheckTitleExact(WebDriver driver) async {
  String title = await driver.title;
  expect(title, 'DartPad (β)');
}
