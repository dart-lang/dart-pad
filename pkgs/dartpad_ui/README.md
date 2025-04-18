# DartPad UI

The main DartPad web UI implemented using [Flutter Web](https://flutter.dev/multi-platform/web).

## How to run

There are options to run UI locally:

1. Run:

   ```
   flutter run -d chrome --web-browser-flag "--disable-web-security"
   ```

   We pass the `--disable-web-security` flag to Chrome as we're not able to
   configure the `flutter run` web server to pass CORS headers for
   `AssetManifest.json`, `FontManifest.json`, and other resources.

2. Open the repo in VS Code, select tab "Run and Debug at the left" and run
   needed configuration.

## How to connect to a local backend

1. In the directory `pkgs/dart_services` run:

    ```
    dart tool/grind.dart build-project-templates
    dart tool/grind.dart build-storage-artifacts
    ```

2. Start the backend as instructed in [dart_services/README](../dart_services/README.md)

3. Run and open UI either by selecting VS code configuration for local backend or by
   passing parameter `channel=localhost` to the UI, for example, with this command:

    ```
    flutter run -d chrome --web-port 8888 --web-browser-flag "--disable-web-security" \
      --web-launch-url=http://localhost:8888/?channel=localhost
    ```

## How to publish

If you want to collaborate on an intermediate version, you can publish it to your own Firebase project:

1. Make sure your current Flutter channel is set to `stable`.

1. Delete git ignored folder `.firebase`, if it exists.

1. In [.firebaserc](./.firebaserc) temporarily change project names.

   ```
   {
      "targets": {
         "<your project name>": {
            "hosting": {
            "dartpad": [
               "<your project name>"
            ]
            }
         }
      }
   }
   ```

1. Run the commands:

   ```
   cd pkgs/dartpad_ui
   flutter build web --wasm
   firebase -P <your project name> init
   ```

   Select `Hosting` (not `App Hosting`) and choose defaults for other questions.

1. Revert all changes, that previous command made in firebase.json, and
   make sure there is only one item under `hosting`, with `"target": "dartpad"`.

1. Run `firebase deploy`

See https://firebase.google.com/docs/hosting.
