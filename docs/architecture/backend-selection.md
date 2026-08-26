# Optional Backend Selection

## Decision

`native_syntax` remains the dependency-free core module. It contains the shared classifications,
capture model, renderer, and backends implemented only with Zig's standard library. A backend that
uses an external parser is exposed as a separate module such as `native_syntax_ziggy`.

External backends are enabled by default. `external-backends=false` disables the complete external
set, while each backend has a matching option such as `backend-ziggy` that can explicitly override
the aggregate default. The package build calls `dependency` and creates a backend module only when
its resolved option is enabled. Disabled parser packages are not configured, compiled, or linked by
the core-only graph.

The external packages are eager manifest dependencies even though their modules remain optional.
With the pinned Zig version, a dependency build that discovers a missing nested lazy dependency can
return before registering its public modules; a clean parent then fails at `dependency.module(...)`.
Making the source dependencies eagerly fetchable gives clean consumers a single-command build while
the backend options still keep unused parser code out of compilation and final binaries.

This structure is preferred over a configured root module because:

- the declarations and dependencies of `native_syntax` do not vary with build options;
- a consumer's imports show which parser packages it selected;
- one optional backend cannot accidentally make another backend reachable;
- consumers continue to own filename and fence-language aliases.

The Zig backend remains available as `native_syntax.languages.zig` because it depends only on the
pinned Zig standard library. Optional external backends are imported directly and do not become
fields of `native_syntax.languages`.

## Consumer Configuration

A core-only consumer disables the external group and imports only its core module:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
    .@"external-backends" = false,
});
consumer.root_module.addImport(
    "native_syntax",
    syntax_dependency.module("native_syntax"),
);
```

The default configuration exposes every external backend module. Consumers still import only the
modules they use:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
});
consumer.root_module.addImport(
    "native_syntax",
    syntax_dependency.module("native_syntax"),
);
consumer.root_module.addImport(
    "native_syntax_ziggy",
    syntax_dependency.module("native_syntax_ziggy"),
);
```

To select only Ziggy, first disable the group and then override that backend:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
    .@"external-backends" = false,
    .@"backend-ziggy" = true,
});
```

Conversely, `.@"backend-ziggy" = false` excludes Ziggy from the default set. Requesting a module
whose resolved option is disabled is a build-configuration error; it fails at build time rather than
silently selecting a fallback parser.

The Ziggy document and schema backends share one pinned package. Either can be excluded independently
with `-Dbackend-ziggy=false` or `-Dbackend-ziggy-schema=false`; enabling both configures the same Ziggy
package once.

The independently pinned Scripty package is likewise controlled by `backend-scripty`. Composed
SuperHTML also consumes Scripty internally, so excluding the standalone Scripty backend does not
remove the dependency while `backend-superhtml` remains enabled.

Markdown follows the same boundary. `-Dbackend-markdown=false` excludes the independently pinned
`zig-markdown-parser` package and `native_syntax_markdown` module. The core module and disabled
backend graph do not import or compile the parser. Consumers remain responsible for aliases such as
`md`, `smd`, or `supermd`.

## Phase 4 Proof

The test-only `backend-dummy` option still exercises lazy selection with a local package. Its build
script rejects configuration unless the parent passes an explicit opt-in value. Consequently:

- `./build.sh test` verifies the core and complete default external set;
- `./build.sh test -Dexternal-backends=false` verifies the dependency-free core configuration;
- `./build.sh test -Dbackend-dummy=true` proves the enabled module imports and calls the dependency;
- `tests/core_only.zig` verifies the optional backend does not leak into the core namespace;
- `tests/optional_dummy.zig` verifies the separately imported backend satisfies the public contract.

The dummy backend is build-system test infrastructure, not a supported language and not part of the
package's compatibility surface.

## Backend Conformance Tests

Every backend supplies language-specific samples to `tests/support/backend_conformance.zig`. The
shared suite verifies empty input, representative valid and malformed input, multiline offsets,
HTML-sensitive bytes, optional invalid UTF-8 input, deterministic captures, range validity, and
source recovery from rendered HTML. Backends can add corpus cases and required scopes without moving
grammar-specific expectations into the core library.
