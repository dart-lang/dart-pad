# WebDriver and Integration tests

### Integration testing

So let's say you have a web app you're working on. You might have a continuous
build set up and running on a service like Travis. Let's say you have some unit
tests written and they're running on each commit on your build system. If you're
very forward looking you might be using a service like coveralls.io to get a
sense of the code coverage from those unit tests.

Imagine you have a continuous build system, and tests, and maybe code coverage.
But what is a green, passing build telling you? You know your unit tests work
and are passing, but you really don't have any insight into whether the app
you're shipping to your users really works. All your tests could pass but the
app itself might fail to load. Or some critical feature of it could fail due to
some component interaction; something that wouldn't be covered by a unit test.

Your unit tests are a very different perspective on the app - a perspective that
your users will never see. In order to have confidence in the application that
you ship, you really need to test the app in a similar way to how your customers
will interact with it. You want to write some integration (or functional) tests
of your app.

For web apps, one way to do that is to use webdriver style tests. Your tests run
on the command-line - not in the browser. They speak a client protocol to a
server or application that can drive a browser. You can tell the browser to
perform actions and verify the browser's state. There are adapters to support
driving all major browsers across a variety of platforms, including mobile
devices.

### Sample test

Here's a sample webdriver test:

```dart
testCheckTitle(WebDriver driver) async {
  String title = await driver.title;
  expect(title, startsWith('DartPad'));
}
```

For this test, the `WebDriver` instance has been set up for us. The browser it's
driving is viewing the DartPad app just built by the build system. In the test
we grab the title of the page, and assert that it's what we expect. There's a
fair amount of asynchronousity with webdriver tests - using `async` / `await`
here can make the code significantly more readable. Besides that - and the
code before the test to get the state set up - it looks very similar to a normal
unit test.

### Getting the environment set up

The basic procedure to get webdriver tests going is:

- start a local webserver serving a copy of your web app. It might be pointed to
  something like `build/web`
- determine the best webdriver client to use. This can be hardcoded in the test
  code, or you can use environment variables to try and auto-select between some
  options.
- create the webdriver instance (https://www.github.com/google/webdriver.dart)
- run your tests using the created webdriver client

### Ways to test

You have some options for applications that a webdriver client can talk to.

#### phantomjs

phantomjs is easy to install and supports headless testing. This is useful as
you don't need a display connected to a computer to run your tests. This can be
valuable in a CI setting.

#### chromedriver

Another app that supports webdriver clients is chromedriver. This tool can be
used to drive instances of Chrome.

#### saucelabs

saucelabs is a very powerful option, especially when used in a continuous build.
saucelabs gives you access to a variety of browsers and platforms. Using it, you
can run your webdriver tests against Chrome/Safari/FireFox/IE, on desktop and
mobile browsers, without any additional complexity in your build setup. It can
give you immediate, up-to-date visibility into whether your app works
cross-browser, cross-platform.

### More info

To see how DartPad is using these technologies, see:

- `test/web_integration.dart`
- `test/src/webdriver.dart`

And the webdriver.dart project:

- https://www.github.com/google/webdriver.dart
