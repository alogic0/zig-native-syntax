# API Guide

The public API currently covers language-neutral scopes, byte ranges, captures, backend metadata,
caller-owned capture storage, source-preserving HTML rendering, and embedded-language composition.

The API remains experimental until the first stable package release. See the
[development plan](plans/development-plan.md) for sequencing and compatibility gates.

The generated [supported-language matrix](supported-languages.md) is the source
of truth for canonical names, aliases, implementation kinds, quality levels,
dependency switches, and each backend's documented subset.

## Configure The Dependency

The default dependency exposes the dependency-free core, every enabled external
backend, and the configured registry:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
});
app.root_module.addImport(
    "native_syntax",
    syntax_dependency.module("native_syntax"),
);
app.root_module.addImport(
    "native_syntax_registry",
    syntax_dependency.module("native_syntax_registry"),
);
```

A dependency-free consumer disables the external group. Core backends and the
configured registry remain available; external parser packages are not
configured, compiled, or linked:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
    .@"external-backends" = false,
});
```

To select only particular external backends, disable the group and enable their
individual switches:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
    .@"external-backends" = false,
    .@"backend-markdown" = true,
    .@"backend-ziggy" = true,
});
```

The complete option and dependency relationships are documented in
[optional backend selection](architecture/backend-selection.md).

## Highlight By Language Name

The configured registry owns aliases and contains only verified, enabled
backends. Unknown and disabled names should use escaped plain text:

```zig
const std = @import("std");
const syntax = @import("native_syntax");
const registry = @import("native_syntax_registry");

fn renderByName(
    allocator: std.mem.Allocator,
    language: []const u8,
    source: []const u8,
    writer: *std.Io.Writer,
) !bool {
    const backend = registry.backendForName(language) orelse {
        try syntax.html.renderPlain(source, writer);
        return false;
    };

    var sink: syntax.CaptureSink = .init(allocator, source.len);
    defer sink.deinit();
    backend.highlight(source, &sink) catch {
        try syntax.html.renderPlain(source, writer);
        return false;
    };
    try syntax.html.render(source, sink.captures(), allocator, writer);
    return true;
}
```

This fallback is safe because highlighting finishes before rendering begins.
Do not retry with plain text after a writer failure from `html.render`, because
the writer may already contain part of the classified result.

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
- Canonical names describe package capabilities; the configured registry owns common aliases.
- `BackendKind` records whether implementation is lexical, parser-backed, or composed.
- `SupportLevel` separately records whether behavior is experimental, verified lexical, or verified
  structural. The configured registry includes only verified backends.
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

The package is pre-1.0. Before the first stable release, public names and
signatures can change when consumer integration exposes a poor boundary. Such
changes must update this guide, the architecture documents, and consumer tests
in the same slice.

The following contracts are already treated as compatibility-sensitive:

- source recovery, HTML escaping, half-open byte ranges, and UTF-8 boundary
  validation cannot be weakened by an ordinary backend change;
- `Scope` names and their `syntax-*` CSS classes are package-controlled;
- removing or renaming a scope, CSS class, canonical language name, or alias is
  a breaking API change after 1.0;
- adding a scope requires release notes because exhaustive consumer switches
  may need updating;
- verified backend classifications may become more precise in compatible
  releases, but source preservation and the documented subset remain required;
- `experimental` backends are excluded from the normal registry and carry no
  behavioral stability promise.

The semantic-versioning and release-note policy will be finalized before 1.0.

## Errors And Allocation

`Backend.highlight` reports allocator failures, invalid capture ranges,
misaligned UTF-8 boundaries, a sink/source length mismatch, or a parser offset
limit through `HighlightError`. Malformed language syntax is not a shared API
error: tolerant backends return partial trusted captures and leave uncertain
bytes unclassified.

`html.render` validates every capture before allocating or writing. Range and
UTF-8 errors therefore cannot leave partial HTML. Allocation or writer failure
is propagated, and temporary renderer storage is released. Once writing has
begun, a writer failure may leave a prefix in the caller-owned destination.

Allocation ownership is explicit:

- `CaptureSink` grows caller-allocated capture storage and releases it from
  `deinit`, unless `toOwnedSlice` transfers that allocation to the caller;
- individual backends may use temporary allocations as documented by their
  compatibility contracts;
- `html.render` temporarily allocates at most two normalization events per
  non-empty capture;
- `html.renderPlain` performs no allocation and is the lowest-cost fallback;
- source bytes, backend metadata, and slices returned by `captures()` remain
  borrowed rather than copied by the core API.

Consumers that require a custom renderer can use `Capture.span`,
`Capture.scope`, and `Scope.cssClass` directly. Captures may overlap or cross,
so a renderer must either normalize those ranges as `html.render` does or use
them as annotations without assuming they form a flat ordered token stream.

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
Ziggy package. External backends are available by default. Consumers that need lookup by language
name import the configured registry rather than enumerating backend modules:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
});

consumer.root_module.addImport(
    "native_syntax_registry",
    syntax_dependency.module("native_syntax_registry"),
);
```

The registry exposes `backends` and `backendForName`; it includes every verified core backend and
each verified external backend enabled by the dependency options. Individual external modules still
expose `backend` for consumers that want explicit selection. The document adapter uses tokenizer
locations for resilient lexical classification. The schema adapter combines those resilient token
captures with recovering AST context for declared types and fields. See the [Ziggy](compatibility/ziggy.md) and
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
spans to markup scopes. The configured registry resolves `md`, `smd`, `supermd`, and
`markdown-inline` to its canonical `markdown` name. See the
[Markdown compatibility note](compatibility/markdown.md) for the exact scope and composition limits.
