FROM dart:beta

# We install unzip and remove the apt-index again to keep the
# docker image diff small.
RUN apt-get update && \
  apt-get install -y unzip && \
  rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN groupadd --system dart && \
  useradd --no-log-init --system --home /home/dart --create-home -g dart dart
RUN chown dart:dart /app

# Work around https://github.com/dart-lang/sdk/issues/47093
RUN find /usr/lib/dart -type d -exec chmod 755 {} \;

# Switch to a new, non-root user to use the flutter tool.
# The Flutter tool won't perform its actions when run as root.
USER dart

COPY --chown=dart:dart tool/dart_cloud_run.sh /dart_runtime/
RUN chmod a+x /dart_runtime/dart_cloud_run.sh
COPY --chown=dart:dart pubspec.* /app/
RUN dart pub get
COPY --chown=dart:dart . /app
RUN dart pub get --offline

ENV PATH="/home/dart/.pub-cache/bin:${PATH}"
ENV FLUTTER_CHANNEL="beta"

# Set the Flutter SDK up for web compilation.
RUN dart pub run grinder setup-flutter-sdk

# Build the dill file
RUN dart pub run grinder build-storage-artifacts validate-storage-artifacts

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []

ENTRYPOINT ["/dart_runtime/dart_cloud_run.sh", "--port", "${PORT}", \
  "--redis-url", "redis://10.0.0.4:6379", "--channel", "beta"]
