# DartPad Probes

Tests in this folder do not run on presubmit, but run on schedule
to verify prod instances of the service.

How to get alerted on failures: https://docs.github.com/en/actions/monitoring-and-troubleshooting-workflows/monitoring-workflows/notifications-for-workflow-runs

Run the tests: `dart test test/probes`.
