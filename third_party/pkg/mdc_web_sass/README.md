# mdc_web_sass
Dart package with Sass files for material-components-web

## Generating

The `tool/generate.dart` script fetches material-components-web from NPM,
applies the required changes to the source files, and generates the contents of
the `lib/` directory:

```bash
dart tool/generate.dart
```

The script changes `@material` imports to `package:` for use with
[`package:sass_builder`](https://pub.dev/packages/sass_builder)