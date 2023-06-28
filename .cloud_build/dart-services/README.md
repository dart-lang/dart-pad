# Dart-services Cloud Build configuration

Cloud Build configuration for dart-services. This runs automatically
using a Cloud Build trigger.

To deploy a new version manually, run:

```
gcloud builds submit \
--config $FLUTTER_CHANNEL.yaml \
--project=dartpad-experiments \
--substitutions \
    REPO_NAME=dart-pad \
    COMMIT_SHA=4b32011ecbda8bb8cc29959d24148085e53e6610
```

Where `$FLUTTER_CHANNEL` is `stable`, `beta`, `dev`, `main`, or `old`.

