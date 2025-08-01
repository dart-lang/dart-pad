# Contributing to DartPad

Want to contribute? Great! First, read this page (including the small print at the end).

## Before you contribute
Before we can use your code, you must sign the [Google Individual Contributor License Agreement](https://developers.google.com/open-source/cla/individual?csw=1) (CLA), which you can do online. The CLA is necessary mainly because you own the copyright to your changes, even after your contribution becomes part of our codebase, so we need your permission to use and distribute your code. We also need to be sure of various other things—for instance that you'll tell us if you know that your code infringes on other people's patents. You don't have to sign the CLA until after you've submitted your code for review and a member has approved it, but you must do it before we can put your code into our codebase.

Before you start working on a larger contribution, you should get in touch with us first through the issue tracker with your idea so that we can help out and possibly guide you. Coordinating up front makes it much easier to avoid frustration later on.

### Code reviews
All submissions, including submissions by project members, require review. We use Github pull requests for this purpose.

### File headers
All files in the project must start with the following header.

    // Copyright (c) 2018, the Dart project authors.  Please see the AUTHORS file
    // for details. All rights reserved. Use of this source code is governed by a
    // BSD-style license that can be found in the LICENSE file.

### The small print
Contributions made by corporations are covered by a different agreement than the one above, the Software Grant and Corporate Contributor License Agreement.

## How to change and add to Sample Gists

1) Update the samples first in the dartpad_examples repository: https://github.com/dart-lang/dartpad_examples

2) If you are updating an existing sample, create your own gist based on the existing samples.
   Gist IDs can be found in the [index file](https://github.com/dart-lang/dart-pad/blob/main/web/index.html#L54).
   Fork the gist, if necessary, then update the contents with the new version from dartpad_examples.

   Otherwise, use the same gist layout as the samples to make sure that DartPad recognizes it:
     * `index.html` for the HTML snippet used to build the output page
     * `styles.css` for the style sheet
     * `main.dart` for the Dart code.

   You can test your gist after updating or creating it by appending the gist ID to the URL for
   dartpad.

3) Add or change sample Gist IDs to the [index file](https://github.com/dart-lang/dart-pad/blob/main/web/index.html#L54),
   and submit a PR for review.

## How to run DartPad locally

To run the server, see the [dart_services readme](pkgs/dart_services/README.md).

To run the front-end, see the [dartpad_ui readme](pkgs/dartpad_ui/README.md).

## Update goldens

When your change requires update to [golden images](https://api.flutter.dev/flutter/flutter_test/matchesGoldenFile.html), run the tests
with flag `--update-goldens`.

## Generate diagrams

If you are getting alerts about cycle references or want to see
dependencies because of other reasons, this is how you can
generate dependency diagrams:

```
cd pkgs/<the package>
dart pub global activate layerlens
layerlens
```

See https://pub.dev/packages/layerlens

## Other

See internal details at go/dartpad-manual.

See code style at doc/CODE_STYLE.md
