# Using Hosted Build Metrics

## What is it?

A hosted metrics service allows you to upload various data metrics and views
graphs of those metrics over time. The service we're using for DartPad is
librato.com.

## How do I get it set up?

- set up an account at librato.com
- add the username and security token to the environment variables for your
  Travis build. You want to use the secure environment variables so that the
  values are not visible in your build logs. You'll generally use `LIBRATO_USER`
  and `LIBRATO_TOKEN` for the env variable names.
- upload the data as part of your build process. Here's an example of how we do
  if for DartPad: `tool/grind.dart`.

You should now be able to see the individual metrics at librato. You can mix and
match different metrics on the same chart as well as put together publicly
visible dashboards.

## What are some of the benefits?

Having detailed historical data for your builds can be useful for a number of
things. In DartPad, we use it to track the size of our compiled front-end. For
web apps you want your page to load as quickly as possible. An important part of
that is keeping your html, css, and compiled JavaScript as small as possible.

For each build, we compile our Dart front-end to JavaScript and upload the size
of that output along with the build's git commit ID. This lets us view the size
of the front-end over time and quickly identify commits that regressed the size.
We've caught significant size regressions size way - times when the front-end
has doubled in size. But it's also good more more subtle regressions; when two
or three commits over a few weeks contributed to a 10-20% size increase.

For the backend of DartPad, we're very concerned with the performance of our
service calls. We've done a lot of work to get the service calls (like code
analysis, compilation, and code completion calls) nice and fast. But code tends
to bit rot and regress, and without closely monitoring the performance there's
no guarentee that our nice fast code will stay fast. So our our backend build
we run a series on benchmarks over our service calls and then upload that data
to librato. We can then use the service to graph that data over time and
identify and major or minor performance regressions.
