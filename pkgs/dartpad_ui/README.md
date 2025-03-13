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

## How to connect to a local backend

1. In the directory `pkgs/dart_services` run:

    ```
    dart tool/grind.dart build-project-templates
    dart tool/grind.dart build-storage-artifacts
    ```

2. Start the backend as instructed in [dart_services/README](../dart_services/README.md)

3. Run and open UI

   Pass parameter `channel=localhost` to the UI.

   This command will start and open the UI connected to local backend:

    ```
    flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
      --web-launch-url=http://localhost:8888/?channel=localhost
    ```
