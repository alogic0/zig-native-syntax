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
Elm has a separate verified structural contract in `elm.md`.

KDL, Nushell, AWK, GDScript,
Common Lisp, Scheme, Elm, PureScript, and Nim use separate
language configurations over shared recovery logic. This coverage does not
resolve names, select dialects, expand macros, validate indentation or types,
parse regex literals, or interpret interpolation and heredoc bodies.

Nix and Fish have separate verified structural contracts in `nix.md` and
`fish.md`.
Elixir has a separate verified structural contract in `elixir.md`.
Julia has a separate verified structural contract in `julia.md`.
Haskell has a separate verified structural contract in `haskell.md`.
Perl has a separate verified structural contract in `perl.md`.
OCaml has a separate verified structural contract in `ocaml.md`.
F# has a separate verified structural contract in `fsharp.md`.
Gleam has a separate verified structural contract in `gleam.md`.

Quoted strings stop at a newline. Unterminated configured block comments
extend to end of input, while subsequent lines recover after unterminated
ordinary strings. Bytes not covered by a configured lexical rule remain plain
source and are always HTML-escaped by the renderer.
