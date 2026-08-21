# Dockerfile Highlighting Compatibility

The dependency-free `dockerfile` backend is a line-oriented lexical scanner.
It recognizes parser directives, standard instructions case-insensitively,
instruction flags, shell-style variables, quoted strings and escapes,
JSON-array punctuation, common operators, and numeric port-like tokens.

The scanner does not parse embedded shell commands, JSON command validity,
BuildKit mount grammar, heredoc bodies, variable expansion semantics, build
stages, or instruction-specific argument rules. Comments are recognized only
as Dockerfile comment lines after indentation. Incomplete quotes and variables
are bounded by the current line so later instructions continue highlighting.
