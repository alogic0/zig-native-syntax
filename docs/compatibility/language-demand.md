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

The repository evidence required native Rust coverage in addition to the
already completed backends. Shell/Bash was included because it is high-value,
bounded, and heavily represented in operational documentation. Both are now
complete. Matching the old Tree-sitter grammar count is not a removal
criterion.

## Further-Language Ranking

No further language is required by the current Zine rendering fixtures. Future
backends should be added only with new consumer evidence. The present ranking
is:

| Priority | Candidate | Rationale and boundary |
| --- | --- | --- |
| 1 | JSON | Common configuration format with a maintained Zig standard-library scanner; small, dependency-free, and low risk. |
| 2 | Diff/patch | Useful in technical writing and operational notes; a line-prefix scanner is bounded and low risk. |
| 3 | TOML | Common project configuration format, but no selected maintained Zig syntax API; requires a documented lexical subset. |
| 4 | Python | Broad user demand, but triple strings, f-strings, indentation, and version drift make a credible scanner substantially larger. |
| 5 | C | Aro offers a maintained Zig parser, but it would be an optional heavyweight dependency and needs a source-range/API audit first. |
| 6 | JavaScript/TypeScript | High general demand but high grammar, JSX/template, dependency-size, and malformed-input complexity; defer until a suitable maintained Zig syntax API exists. |
| 7 | YAML | Common but deceptively context-sensitive; defer without a maintained parser or concrete Zine demand. |

Binary-size and dependency measurements belong to the implementation slice for
any selected candidate. A simple scanner is preferred only when its recovery
rules and plain-text boundary can be stated honestly.
