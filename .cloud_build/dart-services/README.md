# Dart-services Cloud Build configuration

Cloud Build configuration for dart-services. This runs automatically using a
Cloud Build trigger.

To deploy a new version manually, run:

```
gcloud builds submit \
--config $FLUTTER_CHANNEL.yaml \
--project=dart-services \
--substitutions \
    REPO_NAME=dart-pad \
    COMMIT_SHA=$COMMIT_SHA
```

Where `$FLUTTER_CHANNEL` is `stable`, `beta`, `main`, or `old`. The REPO_NAME
and COMMIT_SHA are for adding tags to the Docker image.
