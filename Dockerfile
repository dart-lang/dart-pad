# Keep aligned with min SDK in pubspec.yaml and Dart test version in .travis.yml
FROM google/dart:2.8.1

# The specific commit that dart-services should use. This should be kept
# in sync with the flutter submodule in the dart-services repo.
# To retrieve this value, please run the following in your closest shell:
#
# $ (cd flutter && git rev-parse HEAD)
ARG FLUTTER_COMMIT=e6b34c2b5c96bb95325269a29a84e83ed8909b5f

# We install unzip and remove the apt-index again to keep the
# docker image diff small.
RUN apt-get update && \
  apt-get install -y unzip && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN groupadd --system dart && \
  useradd --no-log-init --system --home /home/dart --create-home -g dart dart
RUN chown dart:dart /app

# Switch to a new, non-root user to use the flutter tool.
# The Flutter tool won't perform its actions when run as root.
USER dart

COPY --chown=dart:dart tool/dart_run.sh /dart_runtime/
COPY --chown=dart:dart pubspec.* /app/
RUN pub get
COPY --chown=dart:dart . /app
RUN pub get --offline

ENV PATH="/home/dart/.pub-cache/bin:${PATH}"

# Clone the flutter repo and set it to the same commit as the flutter submodule.
RUN git clone https://github.com/flutter/flutter.git
RUN cd flutter && git checkout $FLUTTER_COMMIT

# Set the Flutter SDK up for web compilation.
RUN flutter/bin/flutter doctor
RUN flutter/bin/flutter config --enable-web
RUN flutter/bin/flutter precache --web --no-android --no-ios --no-linux \
  --no-windows --no-macos --no-fuchsia

# Build the dill file
RUN pub run grinder build-storage-artifacts validate-storage-artifacts

EXPOSE 8080

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []

ENTRYPOINT /bin/bash /dart_runtime/dart_run.sh
