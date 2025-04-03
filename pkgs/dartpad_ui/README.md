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

1. In .firebaserc temporarily change project names.

   ```
   {
      "projects": {
         "default": "<your project name>"
      },
      "targets": {
         "<your project name>": {
            "hosting": {
               "dartpad": [
                  "<your project name>"
               ],
               "preview": [
                  "<your project name>"
               ]
         ...
   ```

2. Run `firebase init`, select 'Hosting' and go through wizard.

3. Make sure your current Flutter channel is set to `stable`

4. Run the commands:

   ```
   cd pkgs/dartpad_ui
   flutter build web --wasm
   firebase hosting:channel:deploy <your project name>
   ```

See https://firebase.google.com/docs/hosting.
