# Cloud Build configuration for the Firebase SDK

To build and upload to Container Registry, run:

```bash
gcloud builds submit . \
--config=cloudbuild.yaml \
--project=$GCP_PROJECT
```

Where `$GCP_PROJECT` is the Google Cloud project name.

Original source: [cloud-builders-community][].

[cloud-builders-community]: https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile
