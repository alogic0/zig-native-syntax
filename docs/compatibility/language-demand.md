# Language Demand And Fallback Policy

Phase 11 prioritizes compatibility from observed consumer use rather than the
number of grammars bundled by Zine's historical Tree-sitter dependency.

## Zine Audit

The audit covers fenced code in Zine's starter content, generated-site test
fixtures, Markdown compatibility fixtures, documentation, code directives,
and `String.syntaxHighlight` calls.

At the start of Phase 11, generated-site fixtures exercised these categories:

- native package backends: Zig, Ziggy, Ziggy Schema, Scripty, HTML, XML, CSS,
  SuperHTML, and Markdown;
- Zine-owned special handling: `console`;
- remaining Tree-sitter coverage: Rust.

Phase 11 added the Bash and Rust scanners and routed the Rust fixture natively.
The current generated-site fixtures therefore have no required Tree-sitter
language. Zine still tests the compatibility fallback with an unsupported
Python sample until Phase 12 introduces explicit selection modes.

`=html` and `=mathtex` fences are SuperMD rendering directives rather than
source-highlighting language requests. Deliberately invalid labels such as
`zig++` are diagnostic fixtures and are not compatibility targets.

Shell snippets are common throughout contributor-facing documentation even
though the current generated-site fixtures do not contain a `sh` or `bash`
fence. Shell/Bash is therefore the first demand-informed compatibility scanner,
followed by Rust because Rust is required by the rendering snapshot.

## Migration Contract

During the Phase 11 native-first experiment, a language without a native
backend continued through Zine's existing Tree-sitter path. Phase 12 adds
explicit `tree-sitter`, `native-first`, `native-only`, and `off` modes. In
native-only mode, an unsupported language is rendered as safely escaped plain
text while preserving its code-block language class; lack of a highlighter
does not make otherwise valid content fail.

Tree-sitter remains available as a temporary comparison backend while the
ordered native-language roadmap is implemented. Native-only behavior proves
the eventual dependency-free path but does not trigger immediate removal.

Unknown languages still produce the existing diagnostic in the explicit
Tree-sitter compatibility mode. Disabling syntax highlighting continues to
emit safely escaped plain text.

The package exposes canonical backend names only. Zine owns aliases, including
`shell` and `sh` for the future canonical `bash` backend. Adding a backend does
not imply full language conformance: each owned scanner documents the lexical
subset it recognizes and leaves all other bytes unclassified.

## Required Coverage Before Tree-sitter Removal

The repository evidence required native Rust coverage in addition to the
already completed backends. Shell/Bash was included because it is high-value,
bounded, and heavily represented in operational documentation. Both are now
complete. Matching the old Tree-sitter grammar count is not a removal
criterion.

## Further-Language Ranking

No further language is required by the current Zine rendering fixtures. Future
backends should be added only with new consumer evidence. The complete ordered
checklist is maintained in the
[language backend roadmap](../plans/language-roadmap.md). JSON, diff/patch, and
TOML lead because they combine common technical-document use with bounded,
low-risk implementations. High-popularity languages move later when credible
malformed-input handling requires a much larger scanner or a maintained parser
has not been selected.

Binary-size and dependency measurements belong to the implementation slice for
any selected candidate. A simple scanner is preferred only when its recovery
rules and plain-text boundary can be stated honestly.
