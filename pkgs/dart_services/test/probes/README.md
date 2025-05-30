# DartPad Probes

Tests in this folder do not run on presubmit, but run on schedule
to verify prod instances of the service.

## Where to see failures

Check scheduled actions: https://github.com/dart-lang/dart-pad/actions?query=event%3Aschedule

## How to get alerted on failures

It turned out to be challenging to configure alerting for failed probes: [SO Question](https://stackoverflow.com/questions/79622510/how-to-find-out-why-i-am-not-getting-notifications-about-failed-workflow).

It seems the easiest way to set it up is to update workflow to
invoke something that will notify us, like
[build did](https://github.com/dart-lang/build/blob/836f5458f0f73d3d93360666dca584f7d2794141/mono_repo.yaml#L12).

Some options are:

- Invoke a backend endpoint to write a severe log about failure.
- Ping team Chat (see internal information at go/dartpad-alerting).

## How to run the tests

```
cd pkgs/dart_services/
dart test test/probes
```
