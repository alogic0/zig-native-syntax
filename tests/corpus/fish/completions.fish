function __fish_viewer_needs_command --description 'Test whether a command is missing'
    set -l tokens (commandline -opc)
    test (count $tokens[1..-1]) -eq 1
end

function __fish_viewer_files
    command find . -type f \
        -name '*.md' 2>/dev/null
end

complete -c viewer \
    -n __fish_viewer_needs_command \
    -a render \
    -d 'Render Markdown'

complete -c viewer -n '__fish_seen_subcommand_from render' \
    -s o -l output -r -d 'Output path'

if type -q bat && status is-interactive
    viewer README.md | string collect >/tmp/viewer.html &
    /usr/bin/printf '%s\n' $argv[1]
end
