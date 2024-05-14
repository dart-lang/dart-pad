# Cloud Build configuration

Cloud Build configuration files for dart-pad and dart-services.

# Contents

- `dart_pad.yaml` - Deploys `dartpad_ui` to Firebase Hosting
- `dart_services.yaml` - Deploys the dart_services server to Cloud Run

This folder also has configuration files from [cloud-builders-community][],
which are needed to build and deploy `dartpad_ui` to Firebase Hosting:

- `flutter/` - Uploads an image that contains the Flutter SDK to Container Registry
- `firebase/` - Uploads an image that contains the Firebase SDK to Container Registry

# Deploying

These steps are configured as triggers in GCP, but you can also run
them manually.

## Deploy dart_pad

```bash
gcloud builds submit --config .cloud_build/dart_pad.yaml
```

## Deploy dart_services

```bash
gcloud builds submit \ 
  --config .cloud_build/dart_services.yaml \
  --substitutions=<SUBSTITUTIONS> \
  --project=$GCP_PROJECT
```

The substitutions are a comma separated list of `SUBSITUTION=value`:
- `_FLUTTER_CHANNEL` - The Flutter channel to use. (`stable`, `beta`, or `main`)
- `_STORAGE_BUCKET` - The name of the Cloud Storage bucket to use (nnbd_artifacts)
- `_SERVICE_NAME` - The name of the Cloud Run service (dart-services-cloud-run, flutter-beta-channel, or flutter-master-channel)
- `_DEPLOY_REGION` - The region to deploy the Cloud Run service to (us-central1)
- `_REDIS_ADDR` - the IP address of the Redis bucket (10.0.0.4:6379)
- `COMMIT_SHA` - the Git commit SHA for this build. Not required when using Triggers.

## Deploy dartpad_ui:

```bash
gcloud builds submit --config .cloud_build/dart_pad.yaml
```

## Update Flutter SDK images

```bash
gcloud builds submit . --config=.cloud_build/flutter/cloudbuild.yaml
```

## Update the Firebase SDK images

```bash
gcloud builds submit . --config=.cloud_build/firebase/cloudbuild.yaml
```

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile
