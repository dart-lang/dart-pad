# Dart Pad

The UI client for a web based interactive Dart service.

[![Build Status](https://travis-ci.org/dart-lang/dart-pad.svg?branch=master)](https://travis-ci.org/dart-lang/dart-pad)
[![Project Metrics](https://img.shields.io/badge/metrics-librato-blue.svg)](https://metrics.librato.com/share/dashboards/jr4dyv0j?duration=604800)

![](https://github.com/dart-lang/dart-pad/blob/master/doc/images/codepad_ss.jpg)

## What is it? What does it do?

This project is a web based interactive Dart service. It's meant to be a simple,
easy way for users to play with Dart on-line, in a zero-install, zero
configuration environment. It'll support an easy snippet sharing service.

## Project status

Beta - available to play with here: https://dartpad.dartlang.org/, but still a
work in progress.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/dart-pad/issues).

## Running locally

The project contains a tiny appengine for redirecting to gists and the mobile UI. To run this:
- Download the AppEngine SDK for Python here: https://cloud.google.com/appengine/downloads
- Navigate to the root of the checkout folder
- run `pub get`
- run `dart tool/grind.dart build`
- Start the GoogleAppEngineLauncher
- Right click on the empty projects area and select 'Add Existing...' (Mac UI, other platforms may vary a little)
- Add the 'build/web' folder for the location of the project
- Select the project and select 'Run'
- Select the now running project, and click 'browse' - you should now have a fully working local copy of DartPad

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-pad/wiki/Contributing) first. You
can view our license
[here](https://github.com/dart-lang/dart-pad/blob/master/LICENSE).
