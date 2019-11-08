# Keep aligned with min SDK in pubspec.yaml and Dart test version in .travis.yml
FROM google/dart:2.6.0

WORKDIR /app

ADD tool/dart_run.sh /dart_runtime/

RUN chmod 755 /dart_runtime/dart_run.sh && \
  chown root:root /dart_runtime/dart_run.sh

ADD pubspec.* /app/

RUN mkdir /app/third_party
RUN mkdir /app/third_party/pkg

RUN find -name "*" -print

RUN pub get

ADD . /app

RUN pub get --offline

# We install unzip and remove the apt-index again to keep the
# docker image diff small.
RUN apt-get update && \
  apt-get install -y unzip && \
  cp -a third_party/pkg ../pkg && \
  rm -rf /var/lib/apt/lists/*

# The Flutter tool won't perform its actions unless run as root.
RUN groupadd --system dart && \
  useradd --no-log-init --system --home /home/dart --create-home -g dart dart

RUN mkdir /flutter && chown dart:dart /flutter

USER dart

ENV PATH="/home/dart/.pub-cache/bin:${PATH}"

RUN cd / && git clone https://github.com/flutter/flutter.git
RUN /flutter/bin/flutter channel dev
RUN /flutter/bin/flutter upgrade
RUN /flutter/bin/flutter config --enable-web
RUN /flutter/bin/flutter precache --web --no-android --no-ios --no-linux \
  --no-windows --no-macos --no-fuchsia
RUN /flutter/bin/flutter doctor
RUN cat /flutter/bin/cache/dart-sdk/version


EXPOSE 8080 8181 5858

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []

USER root

ENTRYPOINT /bin/bash /dart_runtime/dart_run.sh
