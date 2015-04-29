# Continuous integration

### What is it?

Continuous integration (CI) is a way of running your tests and build process
automatically with each change to your source code. In the context of a Dart
project hosted on Github, you'd use a service like Travis or drone.io to
automatically test your project for each pull request.

### What can it do for you?

A CI system can run your unit tests automatically for each pull request; it can
analyze your Dart code to make sure that there are no errors or warnings. It
can ensure that each change to your source gets tested; not just the changes by
the developers that know how to run the unit tests or that remember to.

Some systems like Travis can write the build status back into a pull request.
You can see in the PR whether the tests passed, and if that PR is safe to merge
into master.

### Getting it set up with Dart projects

Let's say that you wanted to get your project set up with Travis, a common CI
for Dart. You need a metadata file for Travis in the root of your project;
here's a sample metadata file:

`.travis.yml`:

```
language: dart
script: ./tool/travis.sh
```

This file tells Travis you want to use the Dart runtime as well as indicating
the script to run when starting the build. A build script might be as simple as
this:

```
# Fast fail the script on failures.
set -e

# Analyze the source code.
dartanalyzer --fatal-warnings lib/foo.dart

# Run the tests.
dart test/all.dart
```

### See also

- The build script for [dart-pad](https://github.com/dart-lang/dart-pad/blob/master/tool/travis.sh).
- Some sample [build output](https://travis-ci.org/dart-lang/dart-pad/builds/60070710).
