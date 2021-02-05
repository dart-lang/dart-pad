# Keep aligned with min SDK in pubspec.yaml and .github/workflows/dart.yml.
FROM google/dart:2.10.4

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

# Set the Flutter SDK up for web compilation.
RUN dart pub run grinder setup-flutter-sdk

# Build the dill file
RUN dart pub run grinder build-storage-artifacts validate-storage-artifacts

EXPOSE 8080

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []

ENTRYPOINT ["/dart_runtime/dart_run.sh", \
  "--port", "8080", \
  "--proxy-target", "https://v1.api.dartpad.dev/"]
