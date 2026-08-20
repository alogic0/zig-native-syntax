# Experimental API Guide

The public API currently covers language-neutral scopes, byte ranges, captures, backend metadata,
and caller-owned capture storage. HTML rendering and real language backends arrive in later phases.

The API remains experimental until the first stable package release. See the
[development plan](plans/development-plan.md) for sequencing and compatibility gates.

## Render Escaped Plain Text

Code without classifications can be rendered safely without a backend or allocation:

```zig
try syntax.html.renderPlain(source, writer);
```

The function escapes ampersands, angle brackets, and both quote characters. It preserves ordinary
bytes, whitespace, newlines, and invalid UTF-8. It writes only HTML text and does not add a `code` or
`pre` element.

Classified source uses the same escaping path:

```zig
try syntax.html.render(source, sink.captures(), allocator, writer);
```

Captures can be unsorted, duplicated, nested, or crossing. The renderer validates them and emits
non-overlapping segments whose class lists contain the active scopes in deterministic enum order.
Unclassified gaps are escaped without an added span.

The renderer treats source as untrusted bytes. Only library-controlled `span` elements and scope
classes are emitted. Source is escaped in both classified segments and unclassified gaps, including
invalid UTF-8. Property tests verify that stripping generated spans and decoding emitted entities
recovers the original bytes exactly.

Before allocating capture events or writing output, the renderer validates the entire capture set.
Range errors therefore take precedence over allocation and writer failures, and invalid backend
output cannot leave partially rendered HTML. Allocation and writer failures are propagated after all
temporary renderer allocations are released.

## Classify Source

A backend receives borrowed source and reports captures through a sink:

```zig
const std = @import("std");
const syntax = @import("native_syntax");

fn classifyExample(
    source: []const u8,
    sink: *syntax.CaptureSink,
) syntax.HighlightError!void {
    if (std.mem.startsWith(u8, source, "const")) {
        try sink.add(0, 5, .keyword);
    }
}

const example_backend: syntax.Backend = .init(.{
    .canonical_name = "example",
    .display_name = "Example",
    .kind = .lexical,
}, classifyExample);
```

The consumer owns the capture allocation:

```zig
const source = "const answer = 42;";
var sink: syntax.CaptureSink = .init(allocator, source.len);
defer sink.deinit();

try example_backend.highlight(source, &sink);
for (sink.captures()) |capture| {
    const bytes = try capture.span.slice(source);
    const class = capture.scope.cssClass();
    _ = bytes;
    _ = class;
}
```

`CaptureSink.toOwnedSlice` transfers the capture allocation when a consumer needs the result to
outlive the sink. The caller then frees that slice with the same allocator.

## Source And Range Rules

- Source is borrowed and is never copied by the core API.
- Spans use half-open byte ranges `[start, end)`.
- The sink rejects reversed and out-of-bounds ranges before storing them.
- Empty captures are accepted but not stored.
- Identical, nested, and crossing captures are valid.
- Captures retain insertion order until the future renderer normalizes them.
- The HTML renderer normalizes overlapping captures into disjoint output segments.

See the [capture and range model](architecture/capture-model.md) for the complete invariants.

## Classification Rules

`Scope` values are composable. A backend can add two captures over the same span to describe a
builtin type as both `builtin` and `type`. Every scope has a library-controlled CSS class returned by
`Scope.cssClass`.

See the [classification model](architecture/classification-model.md) for mappings and compatibility
rules.

## Backend Rules

- `Backend.init` validates constant metadata at compile time.
- Canonical names describe package capabilities; consumers own aliases.
- A sink must be initialized for the exact source length used in `Backend.highlight`.
- Malformed language syntax is not a shared API error. Backends emit trusted partial captures and
  leave uncertain source unclassified.
- Allocation failure, invalid backend ranges, and source-length mismatch are shared errors.

See the [language backend contract](architecture/backend-contract.md) for the full responsibility and
error boundary.

## Stability

Before the first stable release, names and signatures can change when real backends or the Zine
integration expose a poor boundary. Such changes must update the API guide, architecture documents,
and external-consumer tests in the same slice.

After the first stable release, scope names, CSS classes, range semantics, and public ownership rules
follow the package's documented semantic-versioning policy.
