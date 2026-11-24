# Kraken API for Cloud Run: compiled ahead of time to one native binary on
# an empty base image, so it starts fast and scales to zero cheaply.
FROM dart:3.13.5 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/server.dart -o bin/server

FROM scratch
# The Dart runtime's system libraries and CA certificates.
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
# Cloud Run sets PORT (8080).
CMD ["/app/bin/server"]
