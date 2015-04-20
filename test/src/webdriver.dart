// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library dartpad.test.webdriver;

import 'dart:async';
import 'dart:io';

import 'package:webdriver/io.dart';
import 'package:which/which.dart';

/**
 * Try and determine the best webdriver client to use based on the environment
 * and system.
 */
Future<DriverFactory> createDriverFactory() {
  List<DriverFactory> factories = [
    new SauceLabsDriverFactory(),
    new ChromeDriverFactory(),
    new PhantomJSDriverFactory(),
  ];

  DriverFactory factory;

  for (DriverFactory f in factories) {
    if (f.isAvailable) {
      factory = f;
      break;
    }
  }

  if (factory == null) {
    return new Future.error('''
No webdriver candidates found. Either set up the env. variables for using
saucelabs, or install chromedriver or phantomjs.

See https://github.com/dart-lang/dart-pad/blob/master/doc/webdriver.md
for more information.
''');
  }

  return new Future.value(factory);
}

abstract class DriverFactory {
  final String name;

  DriverFactory(this.name);

  bool get isAvailable;

  Future startFactory();

  Future<WebDriver> createWebDriver();

  Future stopFactory();

  String toString() => name;
}

// env['SAUCE_USERNAME'], env['SAUCE_ACCESS_KEY']
// env['TRAVIS_JOB_NUMBER'] == the named tunnel
// You must set your test's desired capability tunnelIdentifier to the Travis
// job number to use the tunnel
class SauceLabsDriverFactory extends DriverFactory {
  SauceLabsDriverFactory() : super('saucelabs');

  Map get _env => Platform.environment;

  bool get isAvailable => true;
      //_env.containsKey('SAUCE_USERNAME') && _env.containsKey('SAUCE_ACCESS_KEY');

  Future startFactory() => new Future.value(); //isAvailable ?
      //new Future.value() : new Future.error('sauce_connect not available');

  Future<WebDriver> createWebDriver() {
    Map caps = Capabilities.chrome;

    String username = 'devoncarew'; //_env['SAUCE_USERNAME'];
    String accessKey = '0145bdbd-8e1d-4ab7-a677-fc01cded1b47'; //_env['SAUCE_ACCESS_KEY'];

    caps['username'] = username;
    caps['accessKey'] = accessKey;

    String tunnelId = _env['TRAVIS_JOB_NUMBER'];

    if (tunnelId != null) {
      caps['tunnelIdentifier'] = tunnelId;
      caps['tunnel-identifier'] = tunnelId;
    }

    caps['browser'] = {
      "username": username,
      "accessKey": accessKey,
      "os": "Windows 8",
      "browser": "firefox",
      "browserVersion": "29"
    };

    print(caps);

    return createDriver(
        uri: Uri.parse("http://" + username + ":" + accessKey + "@localhost:4445/wd/hub"),
        desired: caps);
  }

  Future stopFactory() => new Future.value();
}

class PhantomJSDriverFactory extends DriverFactory {
  Process _process;

  PhantomJSDriverFactory() : super('phantomjs');

  bool get isAvailable => whichSync('phantomjs', orElse: () => null) != null;

  Future startFactory() {
    return Process.start('phantomjs', ['--webdriver=9515']).then((p) {
      _process = p;
      return new Future.delayed(new Duration(seconds: 1));
    });
  }

  Future<WebDriver> createWebDriver() {
    return createDriver(
        uri: Uri.parse('http://127.0.0.1:9515/wd'),
        desired: Capabilities.chrome);
  }

  Future stopFactory() {
    _process.kill();
    Future f = _process.exitCode;
    _process = null;
    return f;
  }
}

class ChromeDriverFactory extends DriverFactory {
  Process _process;

  ChromeDriverFactory() : super('chromedriver');

  bool get isAvailable => whichSync('chromedriver', orElse: () => null) != null;

  Future startFactory() {
    print('starting chromedriver');

    return Process.start('chromedriver', []).then((p) {
      _process = p;
      return new Future.delayed(new Duration(seconds: 1));
    });
  }

  Future<WebDriver> createWebDriver() {
    Map capabilities = Capabilities.chrome;
    Map env = Platform.environment;
    Map chromeOptions = {};

    if (env['CHROMEDRIVER_BINARY'] != null) {
      chromeOptions['binary'] = env['CHROMEDRIVER_BINARY'];
    }
    if (env['CHROMEDRIVER_ARGS'] != null) {
      chromeOptions['args'] = env['CHROMEDRIVER_ARGS'].split(' ');
    }
    if (chromeOptions.isNotEmpty) {
      capabilities['chromeOptions'] = chromeOptions;
    }

    return createDriver(
        uri: Uri.parse('http://127.0.0.1:9515/wd'),
        desired: capabilities);
  }

  Future stopFactory() {
    print('stopping chromedriver');

    _process.kill();
    Future f = _process.exitCode;
    _process = null;
    return f;
  }
}
