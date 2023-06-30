# Flutter Cloud Build community image

To create and upload new Docker images to Google Container Registry, run: 

```bash
gcloud builds submit . \
--config=cloudbuild.yaml \
--project=$GCP_PROJECT
```

Where `$GCP_PROJECT` is the Google Cloud project name.

This creates and uploads these images:

- gcr.io/$PROJECT_ID/flutter:master
- gcr.io/$PROJECT_ID/flutter:dev
- gcr.io/$PROJECT_ID/flutter:beta
- gcr.io/$PROJECT_ID/flutter:stable
- gcr.io/$PROJECT_ID/flutter

Original source: [cloud-builders-community][].

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile
