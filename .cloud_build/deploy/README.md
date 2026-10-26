# DartPad Deployments

Cloud Build configuration for deploying DartPad to Firebase Hosting.

## Files

- `trigger-pr.yaml` (`deploy-pr`):
    * Trigger for PRs targeting `main`.
    * Deploys to preview channel `pr-<N>` (expires in 7d).
    * External PRs require a `/gcbrun` comment from a maintainer.
- `trigger-main.yaml` (`deploy-main`):
    * Trigger for pushes to `main`.
    * Deploys to the `live` channel (`preview.dartpad.dev`).
- `build.yaml`:
    * Build config that compiles the frontend and writes a `.tar` archive in `gs://dart-pad-build-output`.

## Service Accounts

### `deployer@dart-pad.iam.gserviceaccount.com`
- **Tasks**:
  - Triggered by GitHub PR (`deploy-pr`) or push to `main` (`deploy-main`).
  - Runs **inline** steps defined in the trigger config (cannot be modified by a PR).
  - Stages repo source to `gs://dart-pad-build-input` and submits `build.yaml` as `builder@`.
  - Streams the build log from `gs://dart-pad-build-output` into its build log.
  - Downloads `site.tar` from `gs://dart-pad-build-output`.
  - Extracts `site.tar`, validates `firebase.json`, and deploys `public/` to Firebase Hosting.
  - Publishes build logs to GitHub Checks (so `.github/workflows/deploy_pr_comment.yml` can post the preview URL on the PR).
- **Permissions**:
  - Can deploy to Firebase Hosting.
  - Can submit Cloud Build jobs.
  - Can read/write to `gs://dart-pad-build-logs`, `gs://dart-pad-build-input`, and `gs://dart-pad-build-output`.

### `builder@dart-pad.iam.gserviceaccount.com`
- **Tasks**:
  - Runs `build.yaml`:
    - `dart pub get`
    - `dart run examples/build_examples.dart`
    - `dart run tool/setup_sdk_assets.dart`
    - `jaspr build`
  - Packs `firebase.json` and `public/` into `.tar` and uploads it to `gs://dart-pad-build-output`.
  - Writes build logs to `gs://dart-pad-build-output`.
- **Permissions**:
  - Has **no** Firebase or Cloud Build permissions.
  - Can read `gs://dart-pad-build-input`.
  - Can read/write `gs://dart-pad-build-output`.

## Buckets

### `gs://dart-pad-build-logs`
- **Purpose**: Stores `deploy-pr` and `deploy-main` build logs, so Cloud Build can publish logs to GitHub Checks.
- **Retention**: 30 days.
- **Access**:
   * `deployer@` has read/write,
   * `builder@` has no access.

### `gs://dart-pad-build-input`
- **Purpose**: Stores source tarballs uploaded by `deployer@` when invoking `gcloud builds submit` for the inner build.
- **Retention**: 1 day.
- **Access**:
   * `deployer@` has read/write,
   * `builder@` has read-only.

### `gs://dart-pad-build-output`
- **Purpose**: Stores the built `<uuid>.tar` archive produced by `builder@`.
- **Retention**: 1 day.
- **Access**:
   * `deployer@` has read/write,
   * `builder@` has read/write.

## Updating Triggers

- Changes to `build.yaml` apply automatically.
- Changes to `trigger-*.yaml` must be imported using:
  ```bash
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-pr.yaml
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-main.yaml
  ```
- After first creation, add `id: <uuid>` to `trigger-*.yaml` so subsequent imports update in place:
  ```bash
  gcloud builds triggers describe <name> --project=dart-pad --format='value(id)'
  ```
