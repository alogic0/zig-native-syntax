# Language Demand And Fallback Policy

Phase 11 prioritizes compatibility from observed consumer use rather than the
number of grammars bundled by Zine's historical Tree-sitter dependency.

## Zine Audit

The audit covers fenced code in Zine's starter content, generated-site test
fixtures, Markdown compatibility fixtures, documentation, code directives,
and `String.syntaxHighlight` calls.

Generated-site fixtures currently exercise these categories:

- native package backends: Zig, Ziggy, Ziggy Schema, Scripty, HTML, XML, CSS,
  SuperHTML, and Markdown;
- Zine-owned special handling: `console`;
- remaining Tree-sitter coverage: Rust.

`=html` and `=mathtex` fences are SuperMD rendering directives rather than
source-highlighting language requests. Deliberately invalid labels such as
`zig++` are diagnostic fixtures and are not compatibility targets.

Shell snippets are common throughout contributor-facing documentation even
though the current generated-site fixtures do not contain a `sh` or `bash`
fence. Shell/Bash is therefore the first demand-informed compatibility scanner,
followed by Rust because Rust is required by the rendering snapshot.

## Migration Contract

During the Phase 11 native-first experiment, a language without a native
backend continues through Zine's existing Tree-sitter path. Phase 12 will add
an explicit native-only mode. In that mode, an unsupported language must be
rendered as safely escaped plain text while preserving its code-block language
class; lack of a highlighter must not make otherwise valid content fail.

Unknown languages still produce the existing diagnostic in the explicit
Tree-sitter compatibility mode. Disabling syntax highlighting continues to
emit safely escaped plain text.

The package exposes canonical backend names only. Zine owns aliases, including
`shell` and `sh` for the future canonical `bash` backend. Adding a backend does
not imply full language conformance: each owned scanner documents the lexical
subset it recognizes and leaves all other bytes unclassified.

## Required Coverage Before Tree-sitter Removal

The current repository evidence requires native Rust coverage in addition to
the already completed backends. Shell/Bash is included before removal because
it is high-value, bounded, and heavily represented in operational
documentation. Further languages are ranked separately; matching the old
Tree-sitter grammar count is not a removal criterion.
