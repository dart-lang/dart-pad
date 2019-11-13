# Keep aligned with min SDK in pubspec.yaml and Dart test version in .travis.yml
FROM google/dart:2.6.0

# The specific commit that dart-services should use. This should be kept
# in sync with the flutter submodule in the dart-services repo.
# (run `git rev-parse HEAD` from the flutter submodule to retrieve this value.
ARG FLUTTER_COMMIT=fbabb264e0ab3e090d6ec056e0744aaeb1586735

WORKDIR /app

ADD tool/dart_run.sh /dart_runtime/

RUN chmod 755 /dart_runtime/dart_run.sh && \
  chown root:root /dart_runtime/dart_run.sh

ADD pubspec.* /app/

RUN find -name "*" -print

RUN pub get

ADD . /app

RUN pub get --offline

# We install unzip and remove the apt-index again to keep the
# docker image diff small.
RUN apt-get update && \
  apt-get install -y unzip && \
  rm -rf /var/lib/apt/lists/*

# The Flutter tool won't perform its actions when run as root.
RUN groupadd --system dart && \
  useradd --no-log-init --system --home /home/dart --create-home -g dart dart

RUN mkdir flutter && chown dart:dart flutter

# Switch to a new, non-root user to use the flutter tool.
USER dart

ENV PATH="/home/dart/.pub-cache/bin:${PATH}"

# Clone the flutter repo and set it to the same commit as the flutter submodule.
RUN git clone https://github.com/flutter/flutter.git
RUN cd flutter && git checkout $FLUTTER_COMMIT

# Set the Flutter SDK up for web compilation.
RUN flutter/bin/flutter doctor
RUN flutter/bin/flutter config --enable-web
RUN flutter/bin/flutter precache --web --no-android --no-ios --no-linux \
  --no-windows --no-macos --no-fuchsia
RUN cat flutter/bin/cache/dart-sdk/version

EXPOSE 8080 8181 5858

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []

# Switch back to root to run the application.
USER root

ENTRYPOINT /bin/bash /dart_runtime/dart_run.sh
