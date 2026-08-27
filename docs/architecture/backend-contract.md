# Language Backend Contract

## Decision

A language backend is a small runtime descriptor containing immutable metadata and a classification
function. The classification function receives borrowed source plus a caller-owned `CaptureSink`.
It reports language-neutral captures but does not render HTML.

This keeps language selection independent from rendering and allows optional backend modules to be
excluded from a consumer's dependency graph.

## Metadata

Each backend declares:

- a canonical lowercase name containing letters, digits, and internal hyphens;
- a human-readable display name;
- whether it is lexical, parser-backed, or composed from nested backends;
- an independent support level: experimental, verified lexical, or verified structural.

`BackendKind` describes the implementation mechanism. `SupportLevel` describes the confidence a
consumer can place in its highlighting behavior. A maintained tokenizer can be verified lexical,
while consuming a parser does not automatically make a backend verified. New backends default to
experimental until their expected classifications, recovery, source preservation, and representative
corpus behavior have been reviewed.

Canonical names identify package capabilities. The package also owns a deliberately narrow alias
table for common filename and Markdown-fence labels. Aliases resolve only through the configured
registry and never change backend metadata, CSS classes, or rendered HTML.

`Backend.init` validates constant metadata at compile time. Runtime metadata can be checked with
`BackendInfo.validate` before it is used to construct a registry.

## Capture Sink

The caller creates a sink for the exact source length and retains ownership of it. The sink:

- validates every capture before storing it;
- rejects reversed and out-of-bounds ranges;
- drops empty captures;
- preserves insertion order until the renderer normalizes captures;
- can transfer its allocation to the caller with `toOwnedSlice`.

The sink contains offsets and scopes only. It does not retain the source slice or parser-owned memory.

## Error Contract

The shared highlighting error set contains:

- allocation failure;
- reversed or out-of-bounds backend captures;
- `MisalignedUtf8Boundary` when a capture splits a code point in valid UTF-8 source;
- a mismatch between the source length and the sink's configured source length;
- source too large for a selected parser's checked offset representation.

Malformed or incomplete language syntax is deliberately not a shared highlighting error. A backend
uses its parser's recovery information or lexical tokens to emit the classifications it trusts, then
leaves uncertain bytes unclassified. The renderer later emits those gaps as escaped plain text.

An adapter must translate parser-specific diagnostics into partial classification behavior. Parser
errors must not leak into the shared API merely because an input snippet is incomplete.

After a backend returns, `Backend.highlight` calls the shared `validateCaptures` helper. It checks all
ordinary ranges first. If the complete source is valid UTF-8, it then requires every capture start
and end to be a code-point boundary. Invalid UTF-8 input retains arbitrary-byte captures. The same
helper protects callers that construct captures directly before HTML rendering.

## Configured Registry

The package exposes `native_syntax_registry` alongside the dependency-free core module. It reflects
all core `languages` declarations whose `SupportLevel` is verified, then adds the external backends
enabled by build options. Consequently:

- core use requires only Zig's standard library;
- an unused external parser backend need not be imported or compiled;
- aliases and quality filtering have one package-owned implementation;
- adding a backend does not require a central exhaustive language enum.

External parser adapters use the separate-module and lazy-dependency mechanism defined in
[Optional Backend Selection](backend-selection.md). The core module never imports optional parser
packages.

Composed backends use the source-range translation rules defined in
[Embedded Language Composition](composition.md). The shared helper keeps nested backends unaware of
their parent source offsets.
