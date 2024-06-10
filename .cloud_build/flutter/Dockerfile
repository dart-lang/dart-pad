# Modified for use by DartPad from community builder by Chinmay Garde:
# https://github.com/GoogleCloudPlatform/cloud-builders-community/blob/master/flutter/Dockerfile

FROM debian:bookworm-slim

# Install Dependencies.
RUN apt update -y
RUN apt install -y \
  git \
  wget \
  curl \
  unzip \
  lib32stdc++6 \
  libglu1-mesa

# Install Flutter.
ENV FLUTTER_ROOT="/opt/flutter"


# Set a default channel (branch)
ARG channel=stable

RUN git clone -b $channel https://github.com/flutter/flutter "${FLUTTER_ROOT}"
ENV PATH="${FLUTTER_ROOT}/bin:${PATH}"

# Disable analytics and crash reporting on the builder.
RUN flutter config --disable-analytics

# Perform a doctor run.
RUN flutter doctor -v

# Perform an artifact precache so that no extra assets need to be downloaded on demand.
RUN flutter precache --web

ENTRYPOINT [ "flutter" ]
