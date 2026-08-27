# Roadmap Languages 43–74 Compatibility

The backends from KDL through Nim are dependency-free. RPM Bash delegates to the
parser-backed Bash highlighter; the remaining backends are bounded lexical
scanners. Each recognizes its configured comments, quoted strings and escapes,
numbers, booleans and constants, identifiers, calls, operators, punctuation,
and a documented subset of language keywords and primitive types.

The operational and document formats—SSH config, Git commit and rebase text,
Gettext PO, Typst, DTD, and Ninja receive structural keyword, label, comment,
string, and value scopes
without validation, expansion, or embedded-language parsing. RPM Bash reuses
the owned Bash parser-backed highlighter.

reStructuredText, LaTeX, and Org Mode have separate verified lexical contracts
in `rst.md`, `latex.md`, and `org.md`.
Hurl has a separate verified lexical contract in `hurl.md`.
E-mail has a separate verified lexical contract in `mail.md`.
RPM spec has a separate composed compatibility contract in `rpmspec.md`.

KDL, Fish, Nushell, AWK, GDScript, Perl, Elixir, F#, OCaml, Haskell,
Gleam, Common Lisp, Scheme, Julia, Elm, PureScript, and Nim use separate
language configurations over shared recovery logic. This coverage does not
resolve names, select dialects, expand macros, validate indentation or types,
parse regex literals, or interpret interpolation and heredoc bodies.

Nix has a separate verified structural contract in `nix.md`.

Quoted strings stop at a newline. Unterminated configured block comments
extend to end of input, while subsequent lines recover after unterminated
ordinary strings. Bytes not covered by a configured lexical rule remain plain
source and are always HTML-escaped by the renderer.
