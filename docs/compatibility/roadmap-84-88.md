# Roadmap Languages 84–88 Compatibility

Vimscript and Uxntal use dependency-free bounded lexical scanners. Vimscript
recognizes command keywords and single-quoted strings, and Uxntal recognizes
common opcodes, numbers, raw ASCII starts, and parenthesized comments.

The scanners do not validate Vim command abbreviation or expression context,
or Uxntal stack effects. Vim double quotes are treated as line comments and
single quotes as bounded strings. Uxntal raw ASCII is bounded by a newline
rather than interpreted as an assembler token stream.

The `comment` backend is a dedicated scanner for the generic comment text
injected by Tree-sitter integrations. It recognizes the TODO, note, warning,
and error tag families; optional user suffixes; issue numbers; and HTTP(S)
URLs. It does not own a surrounding source language's comment delimiters and
leaves ordinary comment text unclassified. Consumers compose it only over a
range already identified as comment content.

Agda and Tree-sitter Query have separate parser-backed compatibility contracts
in `agda.md` and `query.md`.

All five backends preserve source ranges and safely recover around malformed
or incomplete input. Unsupported bytes remain unclassified and are escaped by
the shared renderer.
