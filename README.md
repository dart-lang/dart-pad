# DartPad

The UI client for a web based interactive Dart service.

[![Build Status](https://travis-ci.org/dart-lang/dart-pad.svg?branch=master)](https://travis-ci.org/dart-lang/dart-pad)
[![Project Metrics](https://img.shields.io/badge/metrics-librato-blue.svg)](https://metrics.librato.com/share/dashboards/jr4dyv0j?duration=604800)

![](https://github.com/dart-lang/dart-pad/blob/master/doc/images/codepad_ss.jpg)

## What is it? What does it do?

This project is a web based interactive Dart service. It's meant to be a simple,
easy way for users to play with Dart on-line, in a zero-install, zero
configuration environment. It supports an easy snippet sharing service.

## Related projects

See also the [dart-services](https://github.com/dart-lang/dart-services) repo.

## How did we build DartPad?

Interested in the tools we used to build DartPad? We put together some
[documentation](https://github.com/dart-lang/dart-pad/tree/master/doc)
about the hosted services - continuous integration, code coverage, cross-browser testing, ...
that we used to build DartPad.

## Issues and bugs

Please file reports on the
[GitHub Issue Tracker](https://github.com/dart-lang/dart-pad/issues).

### Bug Triage Priorities

Each issue in the tracker will be assigned a priority based on the impact to users when the
issue appears and the number of users impacted (widespread or rare).

Some examples of likely triage priorities:

* P0
  * Broken internal/external navigation links within DartPad
  * JavaScript console errors indicating problems with DartPad functionality in many cases, widespread.
  * App is down / not loading
  * Interface bugs preventing all or almost all uses of the application
  * Unable to compile or analyze valid Dart code (widespread and/or with error messages that aren't retryable)

* P1
  * Unable to compile or analyze valid Dart code in edge cases only, and/or retryable
  * Incorrect or not up-to-date warning information for invalid Dart code (widespread)
  * Interface bugs interfering with common uses of the application, widespread
  * JavaScript console errors indicating problems with DartPad functionality
    (edge cases / not widespread)
  * Enhancements that have significant data around them indicating they are a big win
  * User performance problem (e.g. app loading / run / analysis), widespread
  
* P2
  * Incorrect or not up-to-date warning information for invalid Dart code (edge cases / not widespread)
  * JavaScript errors not resulting in visible problems outside of the console (widespread)
  * Interface bugs interfering with the use of the application in edge cases.
  * User interface and display warts that are not significantly impacting functionality, widespread
  * Enhancements that are agreed to be a good idea even if they don't have data around them indicating
    they are a big win
  * User performance problem (e.g. app loading / run analysis), edge cases / not widespread

* P3
  * Minor user interface warts not significantly impacting functionality, on edge cases only.
  * JavaScript errors not resulting in visible problems outside of the console (edge cases)
  * Enhancements that are speculative or where we are unsure of impacts/tradeoffs

## License and Contributing

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-pad/blob/master/CONTRIBUTING.md) first. You
can view our license
[here](https://github.com/dart-lang/dart-pad/blob/master/LICENSE).
