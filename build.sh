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
    render-bash)
        shift
        exec "${zig_exe}" build render-bash -- "$@"
        ;;
    render-rust)
        shift
        exec "${zig_exe}" build render-rust -- "$@"
        ;;
    render-json)
        shift
        exec "${zig_exe}" build render-json -- "$@"
        ;;
    render-diff)
        shift
        exec "${zig_exe}" build render-diff -- "$@"
        ;;
    render-toml)
        shift
        exec "${zig_exe}" build render-toml -- "$@"
        ;;
    render-dockerfile)
        shift
        exec "${zig_exe}" build render-dockerfile -- "$@"
        ;;
    render-python)
        shift
        exec "${zig_exe}" build render-python -- "$@"
        ;;
    render-sql)
        shift
        exec "${zig_exe}" build render-sql -- "$@"
        ;;
    render-c)
        shift
        exec "${zig_exe}" build render-c -- "$@"
        ;;
    render-javascript)
        shift
        exec "${zig_exe}" build render-javascript -- "$@"
        ;;
    render-typescript)
        shift
        exec "${zig_exe}" build render-typescript -- "$@"
        ;;
    render-ziggy)
        shift
        exec "${zig_exe}" build render-ziggy -Dbackend-ziggy=true -- "$@"
        ;;
    render-ziggy-schema)
        shift
        exec "${zig_exe}" build render-ziggy-schema -Dbackend-ziggy-schema=true -- "$@"
        ;;
    render-scripty)
        shift
        exec "${zig_exe}" build render-scripty -Dbackend-scripty=true -- "$@"
        ;;
    render-html)
        shift
        exec "${zig_exe}" build render-html -Dbackend-html=true -- "$@"
        ;;
    render-xml)
        shift
        exec "${zig_exe}" build render-xml -Dbackend-xml=true -- "$@"
        ;;
    render-css)
        shift
        exec "${zig_exe}" build render-css -Dbackend-css=true -- "$@"
        ;;
    render-superhtml)
        shift
        exec "${zig_exe}" build render-superhtml -Dbackend-superhtml=true -- "$@"
        ;;
    render-markdown)
        shift
        exec "${zig_exe}" build render-markdown -Dbackend-markdown=true -- "$@"
        ;;
esac

exec "${zig_exe}" build "$@"
