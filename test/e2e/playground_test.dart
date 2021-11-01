// Copyright (c) 2021, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'package:grinder/grinder_sdk.dart';
import 'package:test/test.dart';
import 'package:webdriver/io.dart';

bool get runningInCi => Platform.environment.keys.contains('CI');

void main() async {
  late final Process chromedriverProcess;
  late final Process frontEndServer;

  /// Builds the front-end web application.
  void build() {
    // TODO(srawlins): Add options for running against a local back-end.
    PubApp.local('build_runner').run([
      'build',
      '-o',
      'web:build',
      '--delete-conflicting-outputs',
    ]);
  }

  /// Starts the `chromedriver` process.
  // TODO(srawlins): Configure for CI where `chromedriver` should be started
  // outside of the tests, by the CI system. For example:
  // https://github.com/google/webdriver.dart/blob/master/.github/workflows/ci.yaml#L56
  Future<Process> startChromedriver() {
    try {
      return Process.start(
          'chromedriver', ['--port=4444', '--url-base=wd/hub']);
    } on ProcessException {
      print(
          'Error: chromedriver may not be installed. Download and install it, '
          'and make available on \$PATH.');
      rethrow;
    }
  }

  setUpAll(() async {
    build();
    // Start the Chromedriver process
    chromedriverProcess = await startChromedriver();

    await for (String browserOut in const LineSplitter()
        .bind(utf8.decoder.bind(chromedriverProcess.stdout))) {
      if (browserOut.contains('Starting ChromeDriver')) {
        break;
      }
    }

    frontEndServer =
        await Process.start(Platform.executable, ['bin/serve.dart'])
          ..stdout.transform(utf8.decoder).listen(stdout.write);
  });

  tearDownAll(() {
    frontEndServer.kill();
    chromedriverProcess.kill();
  });

  late WebDriver driver;

  /// A simple mechanism that waits for the page to stabilize.
  // TODO(srawlins): Replace this with functionality from Pageloader if we start
  // using that package.
  Future<void> waitForPageToStabilize() async {
    while (true) {
      final versionsElement =
          await driver.findElement(By.id('dartpad-version'));
      if ((await versionsElement.text).isNotEmpty) {
        return;
      }
      await Future.delayed(Duration(seconds: 1));
    }
  }

  setUp(() async {
    // Connect to it with the webdriver package
    driver = await createDriver(
        uri: Uri.parse('http://localhost:4444/wd/hub/'),
        desired: Capabilities.chrome);

    // Go to your page
    await driver.get('http://localhost:8000/');
    await waitForPageToStabilize();
  });

  tearDown(() async {
    await driver.quit();
  });

  Future<void> writeScript(String content) async {
    final codeMirror = await driver.findElement(By.className('CodeMirror'));
    content = content.replaceAll('\n', '\\n');
    await driver
        .execute('arguments[0].CodeMirror.setValue("$content");', [codeMirror]);
  }

  Future<void> runScript() async {
    final runButton = await driver.findElement(By.id('run-button'));
    await runButton.click();
  }

  /// Wait for [sample] to appear in the output panel.
  // TODO(srawlins): Replace this with functionality from Pageloader if we start
  // using that package.
  Future<String> waitForOutput(String sample) async {
    while (true) {
      final outputPanel =
          await driver.findElement(By.id('right-output-panel-content'));
      final text = await outputPanel.text;
      if (text.contains(sample)) {
        return text;
      }
    }
  }

  test('Version text is displayed', () async {
    final versionsElement = await driver.findElement(By.id('dartpad-version'));
    expect(await versionsElement.text, startsWith('Based on Flutter'));
  }, skip: runningInCi);

  test('Basic Dart app', () async {
    await writeScript(r'''
void main() {
  for (var i = 0; i < 4; i++) {
    print('hello $i');
  }
}

''');
    await runScript();
    final text = await waitForOutput('hello');
    expect(text, contains('hello 3'));
  }, skip: runningInCi);
}
