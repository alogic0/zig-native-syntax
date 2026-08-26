# Experimental API Guide

The public API currently covers language-neutral scopes, byte ranges, captures, backend metadata,
caller-owned capture storage, source-preserving HTML rendering, and embedded-language composition.

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
Range errors therefore take precedence over UTF-8-boundary, allocation, and writer failures. For
valid UTF-8 source, a capture that splits a code point fails with `MisalignedUtf8Boundary`; invalid
UTF-8 source retains arbitrary-byte capture behavior. Invalid backend output cannot leave partially
rendered HTML. Allocation and writer failures are propagated after all temporary renderer
allocations are released.

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
    .support_level = .experimental,
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
- `validateCaptures` requires capture starts and ends to be code-point boundaries when the complete
  source is valid UTF-8. Backends and the HTML renderer both enforce this contract.
- Invalid UTF-8 source retains arbitrary-byte capture behavior.
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
- `BackendKind` records whether implementation is lexical, parser-backed, or composed.
- `SupportLevel` separately records whether behavior is experimental, verified lexical, or verified
  structural. Consumers can use it to build a quality-gated registry.
- A sink must be initialized for the exact source length used in `Backend.highlight`.
- After classification, `Backend.highlight` validates the complete capture set, including UTF-8
  boundaries for valid UTF-8 source.
- Malformed language syntax is not a shared API error. Backends emit trusted partial captures and
  leave uncertain source unclassified.
- Allocation failure, invalid backend ranges or UTF-8 boundaries, source-length mismatch, and
  sources too large for a selected parser's offset representation are shared errors.

See the [language backend contract](architecture/backend-contract.md) for the full responsibility and
error boundary.

## Shared Syntax Storage

Parser packages can instantiate `native_syntax.syntax.Model` with their own token, node, and
diagnostic tag enums. The model provides checked byte-offset storage, builders with explicit
ownership transfer, token cursors with bounded lookahead, and recovery synchronization. It does not
provide a grammar or a parser generator.

The source remains caller-owned; a finished tree owns only its token, node, and diagnostic slices.
Language parsers remain responsible for grammar rules and must translate their nodes to stable
highlighting scopes in an adapter. The repository's JavaScript/TypeScript, Bash, and Rust parsers
demonstrate this pattern but remain internal because they are highlighting parsers rather than
public language syntax APIs.

## Compose Embedded Languages

A composed backend can delegate one source range to another backend without making the nested
backend aware of parent offsets:

```zig
try syntax.composition.highlightEmbedded(
    source,
    .{ .start = expression_start, .end = expression_end },
    expression_backend,
    &sink,
);
```

The helper validates the range, highlights the borrowed subslice in a temporary sink, marks the
region as `embedded`, and translates nested captures back into the original source coordinates.
Parent and nested scopes remain composable. See
[embedded language composition](architecture/composition.md) for boundary and failure rules.

## Stability

Before the first stable release, names and signatures can change when real backends or the Zine
integration expose a poor boundary. Such changes must update the API guide, architecture documents,
and external-consumer tests in the same slice.

After the first stable release, scope names, CSS classes, range semantics, and public ownership rules
follow the package's documented semantic-versioning policy.

## Zig Backend

The first native backend uses the pinned Zig standard library tokenizer and recovering AST parser:

```zig
var sink: syntax.CaptureSink = .init(allocator, source.len);
defer sink.deinit();

try syntax.languages.zig.backend.highlight(source, &sink);
try syntax.html.render(source, sink.captures(), allocator, writer);
```

It classifies Zig tokens lexically, recognizes primitive types and values, recovers ordinary comments
from tokenizer trivia, and marks escape sequences inside string and character literals. Recovering
AST context adds function declarations and calls, parameters, declared container and function types,
and member properties. Lexical captures remain available when parsing reports syntax errors.

The backend copies the borrowed source into temporary sentinel-terminated storage required by the
Zig syntax APIs; captures still contain offsets into the caller's original source. Contextual scopes
overlap lexical scopes intentionally and are normalized by the shared HTML renderer.

## External Parser Backends

The Ziggy document and Ziggy Schema adapters are separate modules backed by the same pinned
Ziggy package. External backends are available by default; consumers import only the modules they
use:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
});

consumer.root_module.addImport(
    "native_syntax_ziggy",
    syntax_dependency.module("native_syntax_ziggy"),
);
consumer.root_module.addImport(
    "native_syntax_ziggy_schema",
    syntax_dependency.module("native_syntax_ziggy_schema"),
);
```

Each imported module exposes `backend`. The document adapter uses tokenizer locations for resilient
lexical classification. The schema adapter combines those resilient token captures with recovering
AST context for declared types and fields. See the [Ziggy](compatibility/ziggy.md) and
[Ziggy Schema](compatibility/ziggy-schema.md) compatibility notes for their exact boundaries.

Use `.@"external-backends" = false` for a dependency-free core configuration. Individual options
override that aggregate value, so a core-only configuration can add just Ziggy with
`.@"backend-ziggy" = true`, while a default configuration can exclude it with
`.@"backend-ziggy" = false`.

Scripty is imported from the
`native_syntax_scripty` module. It combines public parser context with bounded lexical recovery; see
the [Scripty compatibility note](compatibility/scripty.md) for the tokenizer API boundary.

Markdown is imported from the
`native_syntax_markdown` module. It maps the standalone Markdown parser's immutable nodes and source
spans to markup scopes. The package exposes only the canonical name `markdown`; filename and fence
aliases remain consumer policy. See the
[Markdown compatibility note](compatibility/markdown.md) for the exact scope and composition limits.
