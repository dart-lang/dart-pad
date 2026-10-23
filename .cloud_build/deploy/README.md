# DartPad Deployments

Cloud Build configuration for building and deploying DartPad to Firebase Hosting.

## Files

- `trigger-pr.yaml` (`deploy-pr`): Trigger for PRs targeting `main`; deploys to preview channel `pr-<N>` (expires in 30d).
- `trigger-main.yaml` (`deploy-main`): Trigger for pushes to `main`; deploys to the `live` channel.
- `build.yaml`: Inner build config that compiles the frontend and writes `firebase.json` + `public/` to a `.tar` archive in `gs://dart-pad-build-output`.

## Security Model

### **`deployer@dart-pad.iam.gserviceaccount.com`**:
- Triggered by GitHub PR or push to `main`.
- Uses **inline** steps, so PRs cannot modify deployment logic.
- Stages source to `gs://dart-pad-build-input`, submits `build.yaml` as `builder@`, and downloads `site.tar` from `gs://dart-pad-build-output`.
- Extracts `site.tar` and validates `firebase.json`.
- Deploys to Firebase Hosting.
- Writes logs to `gs://dart-pad-build-logs` and publishes them to GitHub Checks so `.github/workflows/deploy_pr_comment.yml` can comment the preview URL.

### **`builder@dart-pad.iam.gserviceaccount.com`**:
- Runs `build.yaml`:
  - `dart pub get`
  - `jaspr build`
- Has **no** Firebase or Cloud Build permissions.
- Only has permissions:
  - `logging.logWriter`
  - `artifactregistry.reader`
  - `storage.objectViewer` on `gs://dart-pad-build-input`
  - `storage.objectCreator`, `storage.objectViewer`, and `storage.legacyBucketReader` on `gs://dart-pad-build-output`

## Updating Triggers

- Changes to `build.yaml` apply automatically.
- Changes to `trigger-*.yaml` must be imported into Cloud Build:
  ```bash
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-pr.yaml
  gcloud builds triggers import --project=dart-pad --source=.cloud_build/deploy/trigger-main.yaml
  ```
- After first creation, add `id: <uuid>` to `trigger-*.yaml` so subsequent imports update in place:
  ```bash
  gcloud builds triggers describe <name> --project=dart-pad --format='value(id)'
  ```
