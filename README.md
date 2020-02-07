# DartPad

DartPad is a free, open-source online editor to help developers learn about Dart
and Flutter. You can access it at [dartpad.dev](http://dartpad.dev).

**What is it? What does it do?**

DartPad began as an online playground for the Dart language built by the Dart
tools team in 2015. It compiles, analyzes, and displays the results of its
users' Dart code, and can be embedded in other websites as an iframe.

In Dec 2019, we launched a new version of DartPad (dartpad.dev) with a fresh new
look-and-feel and support for the popular Flutter UI toolkit. To learn more
about the new DartPad, please check this [blog
post](https://medium.com/dartlang/a-brand-new-dartpad-dev-with-flutter-support-16fe6027784).
Interested in embedding DartPad in your websites? Check out this [embedding
guide](https://github.com/dart-lang/dart-pad/wiki/Embedding-Guide).

![DartPad](https://raw.githubusercontent.com/dart-lang/dart-pad/master/doc/images/Sunflower.png)

## **Related projects**

See the [dart-services](https://github.com/dart-lang/dart-services) repo for the
implementation of the backend service that powers compilation for DartPad.

## **How did we build DartPad?**

Interested in the tools we used to build DartPad? We used [Material
components](https://material.io/develop/web/) for the web UI via
[package:mdc_web](https://pub.dev/packages/mdc_web), and Dart for the [backend
services](https://github.com/dart-lang/dart-services) to run compilation. We put
together some [documentation](https://github.com/dart-lang/dart-pad/wiki) about
the hosted services - continuous integration, code coverage, and cross-browser
testing that we used to build DartPad.

## **Issues and bugs**

Please file reports on the [GitHub Issue
Tracker](https://github.com/dart-lang/dart-pad/issues).

### **Bug triage priorities**

Each issue in the tracker will be assigned a priority based on the impact to
users when the issue appears and the number of users impacted (widespread or
rare).

Some examples of likely triage priorities:

*   P0
    *   Broken internal/external navigation links within DartPad
    *   JavaScript console errors indicating problems with DartPad functionality in many cases, widespread.
    *   App is down / not loading
    *   Interface bugs preventing all or almost all uses of the application
    *   Unable to compile or analyze valid Flutter/Dart code (widespread and/or with error messages that aren't retryable)
*   P1
    *   Unable to compile or analyze valid Flutter/Dart code in edge cases only, and/or retryable
    *   Incorrect or not up-to-date warning information for invalid Flutter/Dart code (widespread)
    *   Interface bugs interfering with common uses of the application, widespread
    *   JavaScript console errors indicating problems with DartPad functionality (edge cases / not widespread)
    *   Enhancements that have significant data around them indicating they are a big win
    *   User performance problem (e.g. app loading / run / analysis), widespread
*   P2
    *   Incorrect or not up-to-date warning information for invalid Flutter/Dart code (edge cases / not widespread)
    *   JavaScript errors not resulting in visible problems outside of the console (widespread)
    *   Interface bugs interfering with the use of the application in edge cases.
    *   User interface and display warts that are not significantly impacting functionality, widespread
    *   Enhancements that are agreed to be a good idea even if they don't have data around them indicating they are a big win
    *   User performance problem (e.g. app loading / run analysis), edge cases / not widespread
*   P3
    *   Minor user interface warts not significantly impacting functionality, on edge cases only.
    *   JavaScript errors not resulting in visible problems outside of the console (edge cases)
    *   Enhancements that are speculative or where we are unsure of impacts/tradeoffs

## **License and Contributing**

Contributions welcome! Please read this short
[guide](https://github.com/dart-lang/dart-pad/blob/master/CONTRIBUTING.md)
first. You can view our license
[here](https://github.com/dart-lang/dart-pad/blob/master/LICENSE).


