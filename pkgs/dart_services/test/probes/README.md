# DartPad Probes

Tests in this folder do not run on presubmit, but run on schedule
to verify prod instances of the service.

## How to get alerted on failures

See https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/monitoring-workflows/notifications-for-workflow-runs

## How to run the tests

```
cd pkgs/dart_services/
dart test test/probes
```
