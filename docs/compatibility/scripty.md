# Scripty Highlighting Compatibility

The optional `native_syntax_scripty` module is enabled with `-Dbackend-scripty=true`. It uses the
public parser from the pinned Scripty fork for semantic path and call locations. That revision fixes
parser EOF handling for completed calls followed by trailing whitespace. A small, recovery-oriented
scanner classifies strings, escapes, numbers, booleans, punctuation, and invalid bytes even after the
parser stops at an error.

Scripty currently keeps its tokenizer private. The preferred upstream improvement is to add this
single public declaration to its root module:

```zig
pub const Tokenizer = @import("Tokenizer.zig");
```

The adapter does not copy that private tokenizer. Its local scanner intentionally recognizes only
the bounded lexical subset required for highlighting; the public parser remains the authority for
whether identifiers are global paths, properties, or calls. Once Scripty exports its tokenizer, the
scanner can be replaced with a direct token-to-scope mapping while retaining parser context.

The backend covers global and member paths, chained calls, quoted strings and escapes, integer and
floating-point literals, booleans, structural punctuation, truncated expressions, invalid bytes,
and lexical recovery after parser errors. It is a highlighter rather than a validator, and it does
not expose Scripty parser diagnostics through the shared API.
Unsupported valid Unicode scalars remain unclassified; malformed or truncated UTF-8 bytes retain
the scanner's one-byte invalid behavior.
