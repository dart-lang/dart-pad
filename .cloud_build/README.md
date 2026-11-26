# Cloud Build configuration

Cloud Build configuration files for DartPad.

# Contents

- `deploy/` - Builds and deploys `dartpad_frontend` (PR previews and `main`) to Firebase Hosting
- `firebase/` - Uploads an image that contains the Firebase SDK to Container Registry, from
  [cloud-builders-community][]

# Deploying

These steps are configured as triggers in GCP. See [`deploy/README.md`](deploy/README.md).

## Update the Firebase SDK images

```bash
gcloud builds submit . --config=.cloud_build/firebase/cloudbuild.yaml
```

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/firebase/Dockerfile
