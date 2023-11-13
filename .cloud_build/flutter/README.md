# Flutter Cloud Build community image

To create and upload new Docker images to Google Container Registry, run: 

```bash
gcloud builds submit . \
--config=.cloud_build/flutter/cloudbuild.yaml \
--project=$GCP_PROJECT
```

Where `$GCP_PROJECT` is the Google Cloud project name.

This creates and uploads these images:

- gcr.io/$PROJECT_ID/flutter:main
- gcr.io/$PROJECT_ID/flutter:beta
- gcr.io/$PROJECT_ID/flutter:stable

Original source: [cloud-builders-community][].

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile
