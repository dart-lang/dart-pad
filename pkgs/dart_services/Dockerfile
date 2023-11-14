ARG PROJECT_ID
ARG FLUTTER_CHANNEL
FROM gcr.io/$PROJECT_ID/flutter:$FLUTTER_CHANNEL

WORKDIR /app
COPY . /app

RUN dart pub get
RUN dart compile exe bin/server.dart -o bin/server

RUN dart pub run grinder build-project-templates

EXPOSE 8080
CMD ["/app/bin/server"]
