// Copyright (c) 2015, Google Inc. Please see the AUTHORS file for details.
// All rights reserved. Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

library dartpad.web_integration;

import 'dart:async';
import 'dart:io';

import 'package:http_server/http_server.dart';
import 'package:unittest/unittest.dart';
import 'package:webdriver/webdriver.dart';
import 'package:which/which.dart';

/**
 * - try and determine the best webdriver client to use based on the environment
 *   and system
 * - start a web server on `build/web/`
 * - start a webdriver client (chromedriver, phantomjs, saucelabs)
 * - run the integration tests, providing the tests each their own new webdriver
 *   client and running on a fresh dartpad page
 */
main(List<String> args) async {
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
    print('''
No webdriver candidates found. Either set up the env. variables for using
saucelabs, or install chromedriver or phantomjs.

See https://github.com/dart-lang/dart-pad/blob/master/doc/webdriver.md
for more information.
''');
    exit(1);
  }

  _setupTests(factory);
}

/* WebDriver tests */

// Test that the title is correct - that it starts with "DartPad".
testCheckTitle(WebDriver driver) async {
  String title = await driver.title;
  expect(title, startsWith('DartPad'));
}

testCheckTitleExact(WebDriver driver) async {
  String title = await driver.title;
  expect(title, 'DartPad (β)');
}

/* WebDriver plumbing */

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
      driver = await factory.createDriver();
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

//Future<WebDriver> createDriver() {
//  Map capabilities = Capabilities.chrome;
//  Map env = Platform.environment;
//  Map chromeOptions = {};
//
//  if (env['CHROMEDRIVER_BINARY'] != null) {
//    chromeOptions['binary'] = env['CHROMEDRIVER_BINARY'];
//  }
//  if (env['CHROMEDRIVER_ARGS'] != null) {
//    chromeOptions['args'] = env['CHROMEDRIVER_ARGS'].split(' ');
//  }
//  if (chromeOptions.isNotEmpty) {
//    capabilities['chromeOptions'] = chromeOptions;
//  }
//
//  return WebDriver.createDriver(
//      uri: Uri.parse('http://127.0.0.1:9515/wd'),
//      desiredCapabilities: capabilities);
//}

abstract class DriverFactory {
  final String name;

  DriverFactory(this.name);

  bool get isAvailable;

  Future startFactory();
  Future stopFactory();

  Future<WebDriver> createDriver();

  String toString() => name;
}

class SauceLabsDriverFactory extends DriverFactory {
  SauceLabsDriverFactory() : super('saucelabs');

  bool get isAvailable => false;

  Future startFactory() => new Future.value();
  Future stopFactory() => new Future.value();

  Future<WebDriver> createDriver() => new Future.error('not implemented');
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

  Future stopFactory() {
    _process.kill();
    Future f = _process.exitCode;
    _process = null;
    return f;
  }

  Future<WebDriver> createDriver() {
    return WebDriver.createDriver(
        uri: Uri.parse('http://127.0.0.1:9515/wd'),
        desiredCapabilities: Capabilities.chrome);
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

  Future stopFactory() {
    print('stopping chromedriver');

    _process.kill();
    Future f = _process.exitCode;
    _process = null;
    return f;
  }

  Future<WebDriver> createDriver() {
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

    return WebDriver.createDriver(
        uri: Uri.parse('http://127.0.0.1:9515/wd'),
        desiredCapabilities: capabilities);
  }
}

class MicroServer {
  static Future<MicroServer> start({String path, int port: 8000}) {
    if (path == null) path = '.';

    return HttpServer.bind('0.0.0.0', port).then((server) {
      return new MicroServer._(path, server);
    });
  }

  final String _path;
  final HttpServer _server;
  final StreamController _errorController = new StreamController.broadcast();

  MicroServer._(this._path, this._server) {
    VirtualDirectory vDir = new VirtualDirectory(path);
    vDir.allowDirectoryListing = true;
    vDir.jailRoot = false;

    runZoned(() {
      _server.listen(
          vDir.serveRequest,
          onError: (e) => _errorController.add(e));
    }, onError: (e) => _errorController.add(e));
  }

  String get host => _server.address.host;

  String get path => _path;

  int get port => _server.port;

  String get urlBase => 'http://${host}:${port}/';

  Stream get onError => _errorController.stream;

  Future destroy() => _server.close();
}
