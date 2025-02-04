FROM ubuntu:24.04

# Install required dependencies, including CA certificates
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git \
      curl \
      unzip \
      xz-utils \
      ca-certificates \
      libglu1-mesa && \
    rm -rf /var/lib/apt/lists/*

# Clone the Flutter repository (using the stable channel)
RUN git clone -b stable https://github.com/flutter/flutter.git /opt/flutter

# Set Flutter environment variables
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=$FLUTTER_ROOT/bin:$PATH

# Run Flutter doctor and pre-cache web artifacts
RUN flutter doctor -v && flutter precache --web

WORKDIR /pkgs/dartpad_shared
COPY pkgs/dartpad_shared .

WORKDIR /pkgs/dart_services
COPY pkgs/dart_services .

# Validate Flutter installation and print the Flutter executable path
RUN flutter doctor -v && which flutter

# pubs_dependencies_main.json を仮に複製
RUN cp tool/dependencies/pub_dependencies_main.json \
       tool/dependencies/pub_dependencies_[user-branch].json || true

RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

RUN dart run grinder build-project-templates
RUN dart run grinder build-storage-artifacts

ENV BUILD_SHA=$BUILD_SHA
ENV FLUTTER_ROOT=/opt/flutter
ENV PATH=$FLUTTER_ROOT/bin:$PATH

EXPOSE 8080
CMD ["/pkgs/dart_services/bin/server"]