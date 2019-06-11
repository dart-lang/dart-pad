# Keep aligned with min SDK in pubspec.yaml and Dart test version in .travis.yml
FROM google/dart:2.3.2

WORKDIR /app
ADD tool/dart_run.sh /dart_runtime/
RUN chmod 755 /dart_runtime/dart_run.sh && \
  chown root:root /dart_runtime/dart_run.sh
ADD pubspec.* /app/
ADD third_party /app/third_party
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

EXPOSE 8080 8181 5858

# Clear out any arguments the base images might have set and ensure we start
# the Dart app using custom script enabling debug modes.
CMD []
ENTRYPOINT /bin/bash /dart_runtime/dart_run.sh
