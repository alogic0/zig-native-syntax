#!/bin/sh
set -eu

zig_version="0.17.0-dev.1756+613c03321"
zig_exe="${HOME}/.zig/${zig_version}/files/zig"

if [ ! -x "${zig_exe}" ]; then
    echo "required Zig compiler not found or not executable: ${zig_exe}" >&2
    exit 1
fi

case "${1:-}" in
    render-zig)
        shift
        exec "${zig_exe}" build render-zig -- "$@"
        ;;
    render-ziggy)
        shift
        exec "${zig_exe}" build render-ziggy -Dbackend-ziggy=true -- "$@"
        ;;
    render-ziggy-schema)
        shift
        exec "${zig_exe}" build render-ziggy-schema -Dbackend-ziggy-schema=true -- "$@"
        ;;
esac

exec "${zig_exe}" build "$@"
