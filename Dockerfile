ARG BUILD_SHA

FROM instrumentisto/flutter:latest


WORKDIR /pkgs/dartpad_shared
COPY pkgs/dartpad_shared .

WORKDIR /pkgs/dart_services
COPY pkgs/dart_services .

RUN flutter doctor -v

# pubs_dependencies_main.json を仮に複製
RUN cp tool/dependencies/pub_dependencies_main.json \
       tool/dependencies/pub_dependencies_[user-branch].json || true

RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

RUN dart run grinder build-project-templates
RUN dart run grinder build-storage-artifacts

ENV BUILD_SHA=$BUILD_SHA

EXPOSE 8080
CMD ["/app/bin/server"]