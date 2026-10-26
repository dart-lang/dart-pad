# DartPad Deployments

Cloud Build configuration for building and deploying DartPad (`pkgs/dartpad_preview/dartpad_frontend`) to Firebase Hosting (`sketch-pad-1cebb` in project `dart-pad`).

## Files

- `trigger-pr.yaml` (`deploy-pr`): Trigger for PRs targeting `main`; deploys to preview channel `pr-<N>` (expires in 7d). For PRs from external contributors, a maintainer can comment `/gcbrun` on the PR to trigger the build.
- `trigger-main.yaml` (`deploy-main`): Trigger for pushes to `main`; deploys to the `live` channel (`preview.dartpad.dev`).
- `build.yaml`: Inner build config that compiles the frontend and writes `firebase.json` + `public/` to a `.tar` archive in `gs://dart-pad-build-output`.

## Service Accounts

### `deployer@dart-pad.iam.gserviceaccount.com`
- **Tasks**:
  - Triggered by GitHub PR (`deploy-pr`) or push to `main` (`deploy-main`).
  - Runs **inline** steps defined in the trigger config, so untrusted PR code cannot modify the deployment steps.
  - Stages repo source to `gs://dart-pad-build-input` and submits `build.yaml` as `builder@`.
  - Streams the inner build log from `gs://dart-pad-build-output` into the outer build log.
  - Downloads `site.tar` from `gs://dart-pad-build-output` and deletes the temporary tarball.
  - Extracts `site.tar`, validates `firebase.json`, and deploys `public/` to Firebase Hosting (`sketch-pad-1cebb`).
  - Writes outer build logs to `gs://dart-pad-build-logs` and publishes them to GitHub Checks so `.github/workflows/deploy_pr_comment.yml` can post the preview URL on the PR.
- **Permissions**:
  - `firebasehosting.admin` and `serviceusage.serviceUsageViewer` (to deploy to Firebase Hosting)
  - `cloudbuild.builds.editor` (to submit the inner `build.yaml` build)
  - `iam.serviceAccountUser` on `builder@dart-pad.iam.gserviceaccount.com` (to run the inner build as `builder@`)
  - `logging.logWriter` and `artifactregistry.reader`
  - `storage.objectAdmin` and `storage.legacyBucketReader` on `gs://dart-pad-build-logs`, `gs://dart-pad-build-input`, and `gs://dart-pad-build-output`

### `builder@dart-pad.iam.gserviceaccount.com`
- **Tasks**:
  - Runs `build.yaml`:
    - `dart pub get`
    - `dart run examples/build_examples.dart`
    - `dart run tool/setup_sdk_assets.dart`
    - `jaspr build`
  - Packs `firebase.json` and `public/` into `<uuid>.tar` and uploads it to `gs://dart-pad-build-output`.
  - Writes inner build logs to `gs://dart-pad-build-output` (`logStreamingOption: STREAM_OFF`).
- **Permissions**:
  - Has **no** Firebase or Cloud Build permissions.
  - `logging.logWriter` and `artifactregistry.reader`
  - `storage.objectViewer` on `gs://dart-pad-build-input` (read-only access to staged source)
  - `storage.objectCreator`, `storage.objectViewer`, and `storage.legacyBucketReader` on `gs://dart-pad-build-output` (can create new objects, but cannot overwrite or delete existing objects)

## Buckets

### `gs://dart-pad-build-logs`
- **Purpose**: Stores outer `deploy-pr` and `deploy-main` build logs so Cloud Build can publish logs to GitHub Checks (`includeBuildLogs: INCLUDE_BUILD_LOGS_WITH_STATUS`).
- **Retention**: 30 days.
- **Access**: `deployer@` has read/write (`storage.objectAdmin`, `storage.legacyBucketReader`); `builder@` has no access.

### `gs://dart-pad-build-input`
- **Purpose**: Stages source tarballs uploaded by `deployer@` when invoking `gcloud builds submit` for the inner build.
- **Retention**: 1 day.
- **Access**: `deployer@` has read/write (`storage.objectAdmin`, `storage.legacyBucketReader`); `builder@` has read-only (`storage.objectViewer`).

### `gs://dart-pad-build-output`
- **Purpose**: Stores the compiled `<uuid>.tar` site archive and the inner build's `log-<build_id>.txt` file produced by `builder@`.
- **Retention**: 1 day.
- **Access**: `deployer@` has full read/write/delete (`storage.objectAdmin`, `storage.legacyBucketReader`); `builder@` has create/read (`storage.objectCreator`, `storage.objectViewer`, `storage.legacyBucketReader`).

## Updating Triggers

- Changes to `build.yaml` apply automatically.
- Changes to `trigger-*.yaml` must be imported into Cloud Build (requires `iam.serviceAccountUser` on `deployer@`, granted to `group:dartpad-maintainers@twosync.google.com`):
  ```bash
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-pr.yaml
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-main.yaml
  ```
- After first creation, add `id: <uuid>` to `trigger-*.yaml` so subsequent imports update in place:
  ```bash
  gcloud builds triggers describe <name> --project=dart-pad --format='value(id)'
  ```
