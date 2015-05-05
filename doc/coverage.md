# Getting your project set up with code coverage

Code coverage is awesome! [coveralls.io](https://coveralls.io/) is awesome!
Here's how you use them together in a Dart project. These instructions assume
you're running your builds on Travis, but they'll will work for most continuous
integration systems.

### Turn on support for your project at coveralls.io

Go to https://coveralls.io/repos/new and add your repo to coveralls. As part of 
this process you'll get a repo token; this is the token that will allow your CI
to upload coverage information with each build.

### Configure your CI

Go to the admin page for your project on Travis (or your favorite CI). Under
`Settings` > `Environment Variables`, add a new environment variable. Call it
something like `COVERAGE_TOKEN`, and for it's value put in the coveralls.io
token you got from the last step. You want to make sure the `Display value in
build logs` setting is `off`.

### Gather coverage info

Now you'll want to adjust your build script to run your unit tests, gather
coverage, and upload the information to coveralls.io with your handy repo token.
Fortunately, there's a Pub package to automate all this for you. Add this bit of
code to your Travis shell script (typically something like `tool/travis.sh`):

```shell
# Install dart_coveralls; gather and send coverage data.
if [ "$COVERAGE_TOKEN" ]; then
  pub global activate dart_coveralls
  pub global run dart_coveralls report \
    --token $COVERAGE_TOKEN \
    --retry 2 \
    --exclude-test-files \
    test/all.dart
fi
```

You'll want to adjust that script for the name of the main test entrypoint file
and the name of the environment variable you stored the repo token in.

# Brag about your coverage!

To wrap up, you'll want to put a coveralls badge on your project to give
yourself and others awareness of your coverage. From the project page in
coveralls.io you should see a `Readme badge` section. Copy the badge for
markdown files, and paste that into the readme.md file for your project.

That's it! The next time your commit to your project or get a PR, travis will
run, `dart_coveralls` will run your tests and gather coverage, and it'll all be
uploaded to coveralls.io. You'll have full visibility into your coverage and be
able to track it over time. With the coveralls UI, you can even set triggers to
get notifications if your coverage goes below a certain level, or regresses more
than a certain amount in one PR.
