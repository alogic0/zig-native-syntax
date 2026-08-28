# Roadmap Languages 84–88 Compatibility

Uxntal uses a dependency-free bounded lexical scanner. It recognizes common
opcodes, numbers, raw ASCII starts, and parenthesized comments.

The scanner does not validate Uxntal stack effects. Raw ASCII is bounded by a
newline rather than interpreted as an assembler token stream.

The `comment` backend is a dedicated scanner for the generic comment text
injected by Tree-sitter integrations. It recognizes the TODO, note, warning,
and error tag families; optional user suffixes; issue numbers; and HTTP(S)
URLs. It does not own a surrounding source language's comment delimiters and
leaves ordinary comment text unclassified. Consumers compose it only over a
range already identified as comment content.

Agda, Tree-sitter Query, and Vimscript have separate parser-backed compatibility
contracts in `agda.md`, `query.md`, and `vim.md`.

All five backends preserve source ranges and safely recover around malformed
or incomplete input. Unsupported bytes remain unclassified and are escaped by
the shared renderer.
