# Cloud Build configuration

Cloud Build configuration files for dart-pad and dart-services.

# Contents

- `dart-services/` - Deploys the dart_services server to Cloud Run - `flutter/`
- `dart_pad.yaml` - Deploys `dart_pad` to Firebase Hosting
- `sketch_pad.yaml` - Deploys `sketch_pad` to Firebase Hosting

This folder also has configuration files from [cloud-builders-community][],
which are needed to build and deploy `dart_pad` and `sketch_pad` to Firebase
Hosting:

- Uploads an image that contains the Flutter SDK to Container Registry -
  `firebase/`
- Uploads an image that contains the Firebase SDK to Container Registry

# Deploying

These steps are configured as triggers in GCP, but you can also run
them manually.

Deploy dart_pad:

```bash
gcloud builds submit --config .cloud_build/dart_pad.yaml
```

To deploy sketch_pad:

```bash
gcloud builds submit --config .cloud_build/sketch_pad.yaml
```

Update the Flutter SDK images:

```bash
gcloud builds submit . --config=.cloud_build/flutter/cloudbuild.yaml
```

Update the Firebase SDK images:

```bash
gcloud builds submit . --config=.cloud_build/firebase/cloudbuild.yaml
```

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile
