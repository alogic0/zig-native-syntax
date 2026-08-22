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

Phase 11 added the initial Bash and Rust scanners and routed the Rust fixture natively.
The current generated-site fixtures therefore have no required Tree-sitter
language. Phase 12 exercised the compatibility fallback with a deliberately
unsupported language before removing the old backend.

`=html` and `=mathtex` fences are SuperMD rendering directives rather than
source-highlighting language requests. Deliberately invalid labels such as
`zig++` are diagnostic fixtures and are not compatibility targets.

Shell snippets are common throughout contributor-facing documentation even
though the current generated-site fixtures do not contain a `sh` or `bash`
fence. Shell/Bash therefore began as the first demand-informed compatibility
scanner and later migrated to a parser-backed implementation. Rust followed
the same migration path because it is required by the rendering snapshot.

## Final Migration Contract

During the experiment, a language without a native backend continued through
Zine's existing Tree-sitter path. Temporary `tree-sitter`, `native-first`,
`native-only`, and `off` modes made the comparison explicit.

The final audit covered every former Flow file type and allowed Zine to remove
the Flow and Tree-sitter highlighting dependencies. Zine now exposes `native`
and `off`, with native as the default. In either mode, an unsupported language
is rendered as safely escaped plain text while preserving its code-block
language class; lack of a highlighter does not make otherwise valid content
fail.

Disabling syntax highlighting continues to emit safely escaped plain text.

The package exposes canonical backend names only. Zine owns aliases, including
`shell` and `sh` for the canonical `bash` backend. Adding a backend does
not imply full language conformance: each owned backend documents the syntax
subset it recognizes and leaves all other bytes unclassified.

## Removal Evidence

The repository evidence required native Rust coverage in addition to the
already completed backends. Shell/Bash was included because it is high-value,
bounded, and heavily represented in operational documentation. Both are now
complete. The eventual inventory audit covered all 93 former Flow file-type
names through 87 direct native routes and six intentional reused backends.
Matching a grammar count alone was not the removal criterion; aliases,
unsupported-language behavior, generated rendering, build modes, and host
validation were also checked.

## Further-Language Ranking

No further language is required by the current Zine rendering fixtures. Future
backends should be added only with new consumer evidence. The complete ordered
checklist is maintained in the
[language backend roadmap](../plans/language-roadmap.md). All listed backends
are now complete. Any future language additions remain prioritized by
technical-document use, implementation bounds, and credible malformed-input
recovery rather than by popularity alone.

Binary-size and dependency measurements belong to the implementation slice for
any selected candidate. A simple scanner is preferred only when its recovery
rules and plain-text boundary can be stated honestly.
