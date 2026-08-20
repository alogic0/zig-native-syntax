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
- whether it is lexical, parser-backed, or composed from nested backends.

Canonical names identify package capabilities. They are not filename extensions, Markdown fence
aliases, CSS classes, or HTML content. A consumer such as Zine owns mappings from its accepted aliases
to enabled backends.

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
- a mismatch between the source length and the sink's configured source length.

Malformed or incomplete language syntax is deliberately not a shared highlighting error. A backend
uses its parser's recovery information or lexical tokens to emit the classifications it trusts, then
leaves uncertain bytes unclassified. The renderer later emits those gaps as escaped plain text.

An adapter must translate parser-specific diagnostics into partial classification behavior. Parser
errors must not leak into the shared API merely because an input snippet is incomplete.

## Optional Backends

The core package does not maintain a global runtime registry. Backend modules export descriptors, and
consumers or a future configured module choose which descriptors to include. Consequently:

- core use requires only Zig's standard library;
- an unused external parser backend need not be imported or compiled;
- consumer aliases do not expand the core API;
- adding a backend does not require a central exhaustive language enum.

External parser adapters use the separate-module and lazy-dependency mechanism defined in
[Optional Backend Selection](backend-selection.md). The core module never imports optional parser
packages.
