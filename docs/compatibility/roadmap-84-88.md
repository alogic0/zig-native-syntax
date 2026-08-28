# Roadmap Languages 84–88 Compatibility

The `comment` backend is a dedicated scanner for the generic comment text
injected by Tree-sitter integrations. It recognizes the TODO, note, warning,
and error tag families; optional user suffixes; issue numbers; and HTTP(S)
URLs. It does not own a surrounding source language's comment delimiters and
leaves ordinary comment text unclassified. Consumers compose it only over a
range already identified as comment content.

Agda, Tree-sitter Query, Vimscript, and Uxntal have separate compatibility
contracts in `agda.md`, `query.md`, `vim.md`, and `uxntal.md`.

All five backends preserve source ranges and safely recover around malformed
or incomplete input. Unsupported bytes remain unclassified and are escaped by
the shared renderer.
