# Vimscript Compatibility

The Vimscript backend layers an owned, tolerant structural pass over its
bounded lexical scanner. It recognizes legacy `function[!]` declarations,
Vim9 `def` declarations, parameters, `let`/`const`/`var`/`final` bindings,
scope-prefixed variables, function calls, member access, import aliases, and
user-command names.

The parser deliberately accepts incomplete lines and does not execute Vim's
command-abbreviation rules or infer expression types. Double quotes retain the
legacy line-comment policy and single quotes retain bounded string handling.
Vim9 line-leading `#` comments are also recognized. Unsupported text stays
unclassified and malformed bytes retain the shared arbitrary-byte recovery.
