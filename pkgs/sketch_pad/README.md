## SketchPad

An experimental redux of the DartPad UI.

## Status?

This is an experimental re-imagining of the DartPad UI. Goals include:

- re-writing the front-end in Flutter Web
- having a simple, visually interesting UI
- keeping the number of use cases small; for example, currently only Dart
  snippets and Flutter web apps are supported

## How to run

To run this locally, run:

```
flutter run -d chrome --web-browser-flag "--disable-web-security"
```

Above, we pass the `--disable-web-security` to Chrome as we're not able to
configure the web server used by `flutter run` to pass CORS headers for the
`AssetManifest.json`, `FontManifest.json`, and other resources.
