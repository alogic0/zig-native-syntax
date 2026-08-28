# Fish highlighting

The verified structural Fish backend tracks command positions across lines,
pipelines, control commands, and command substitutions. It distinguishes
function declarations and calls, builtin commands, declared variables,
function parameters, options, sliced variable expansions, command decorators,
redirections, and variable expansion in double-quoted text. Line continuations
retain the surrounding command context, including common Fish
completion definitions. It remains tolerant and does not execute expansions or
validate commands.
