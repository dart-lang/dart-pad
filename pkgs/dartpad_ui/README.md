# DartPad UI

The main DartPad web UI implemented using [Flutter Web](https://flutter.dev/multi-platform/web).

## How to run

To run this locally, run:

```
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

We pass the `--disable-web-security` flag to Chrome as we're not able to
configure the `flutter run` web server to pass CORS headers for
`AssetManifest.json`, `FontManifest.json`, and other resources.
