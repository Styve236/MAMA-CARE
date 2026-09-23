# Build stage
FROM dart:stable AS build
WORKDIR /app

# Cache dependencies
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get

# Copy sources
COPY lib ./lib
COPY bin ./bin

# Compile a self-contained server binary
RUN dart compile exe bin/server.dart -o bin/server

# Runtime stage
FROM dart:stable
WORKDIR /app
COPY --from=build /app/bin/server ./bin/server
EXPOSE 3000
CMD ["./bin/server"]