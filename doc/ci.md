# Continuous integration

### What is it?

Continuous integration (CI) is a way of running your tests and build process
automatically with each change to your source code. In the context of a Dart
project hosted on Github, you'd use a service like GitHub Actions to
automatically test your project for each pull request.

### What can it do for you?

A CI system can run your unit tests automatically for each pull request; it can
analyze your Dart code to make sure that there are no errors or warnings. It
can ensure that each change to your source gets tested; not just the changes by
the developers that know how to run the unit tests or that remember to.

CI systems typically write the build status back into a pull request.
You can see in the PR whether the tests passed, and if that PR is safe to merge
into master.

### Getting it set up with Dart projects

For documentation on setting up Dart CI testing with GitHub Actions,
see the [`setup-dart`](https://github.com/marketplace/actions/setup-dart-sdk)
GitHub Action.

### See also

- The GitHub action workflow for [dart-pad](https://github.com/dart-lang/dart-pad/blob/master/.github/workflows/dart.yml).
- Some sample [build output](https://github.com/dart-lang/dart-pad/actions/runs/1168537794).
