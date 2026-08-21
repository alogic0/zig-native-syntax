# Bash Highlighting Compatibility

The dependency-free `bash` backend is available as
`native_syntax.languages.bash`. Its canonical name is `bash`; consumers own
aliases such as `sh` and `shell`.

This is a source-preserving lexical scanner, not a shell parser or validator.
It recognizes:

- line comments and shebangs;
- single, double, ANSI-C, and locale-style quoted strings;
- backslash escapes in expandable strings and ordinary source;
- named, positional, special, and braced variables;
- command substitutions using `$()` and backticks;
- arithmetic substitutions using `$((...))`;
- common control-flow keywords;
- decimal digit runs;
- common control, pipeline, redirection, and grouping operators;
- simple static heredoc delimiters, quoted delimiters, `<<-` tab stripping,
  bodies, and terminators.

Nested captures are intentional: variables, escapes, and substitutions inside
double-quoted strings overlap the enclosing `string` capture. The shared HTML
renderer normalizes these scopes without changing source bytes.

The scanner does not expand shell words, resolve aliases, classify command
names, validate control-flow structure, interpret parameter-expansion
operators, or implement runtime heredoc delimiter expansion. Complex dynamic
heredoc delimiters and grammar-dependent uses of reserved words may remain
plain text or receive only their safe lexical classification. Unterminated
quotes, substitutions, and heredocs extend to end of input and remain safely
escaped rather than producing a highlighting error.
