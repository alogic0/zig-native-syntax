# syntax=docker/dockerfile:1.7
FROM alpine:3.21 AS build
RUN --mount=type=cache,target=/root/.cache \
    zig build -Doptimize=ReleaseSafe
RUN <<'SCRIPT'
set -eu
echo "building $TARGET"
SCRIPT
COPY --from=build /src/zig-out/bin/server ./server
ENTRYPOINT ["./server", "--port", "8080"]
