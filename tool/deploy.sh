#!/usr/bin/env bash
$(boot2docker shellinit)
gcloud preview app deploy app.yaml
VERSION=$(grep ^version app.yaml | sed 's/version: //')
dart tool/warmup.dart $VERSION
