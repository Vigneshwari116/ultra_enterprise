# Test / staging API — Dart SDK is only needed at build time; runtime uses compiled exe + Dart runtime.
FROM dart:3.5.4 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN dart pub get
COPY bin bin
COPY lib lib
RUN dart pub get
RUN dart compile exe bin/server.dart -o /app/ultra_api_server

FROM debian:bookworm-slim
RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates \
  && rm -rf /var/lib/apt/lists/*
COPY --from=build /runtime/ /runtime/
COPY --from=build /app/ultra_api_server /app/ultra_api_server
WORKDIR /app
ENV PORT=3000
EXPOSE 3000
USER nobody
ENTRYPOINT ["/app/ultra_api_server"]
