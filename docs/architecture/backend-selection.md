# Optional Backend Selection

## Decision

`native_syntax` remains the dependency-free core module. It contains the shared classifications,
capture model, renderer, and backends implemented only with Zig's standard library. A backend that
uses an external parser is exposed as a separate module such as `native_syntax_ziggy`.

Each external backend has a matching build option, such as `backend-ziggy`. The package build calls
`lazyDependency` and creates that backend module only when the option is enabled. Disabled parser
packages are therefore not fetched, configured, compiled, or linked by the core-only graph.

This structure is preferred over a configured root module because:

- the declarations and dependencies of `native_syntax` do not vary with build options;
- a consumer's imports show which parser packages it selected;
- one optional backend cannot accidentally make another backend reachable;
- consumers continue to own filename and fence-language aliases.

The Zig backend remains available as `native_syntax.languages.zig` because it depends only on the
pinned Zig standard library. Optional external backends are imported directly and do not become
fields of `native_syntax.languages`.

## Consumer Configuration

A core-only consumer configures the package normally and imports only its core module:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
});
consumer.root_module.addImport(
    "native_syntax",
    syntax_dependency.module("native_syntax"),
);
```

An optional backend is enabled on the dependency and imported separately:

```zig
const syntax_dependency = b.dependency("zig_native_syntax", .{
    .target = target,
    .optimize = optimize,
    .@"backend-ziggy" = true,
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

Requesting an optional module without enabling its matching option is a build-configuration error.
This fails at build time rather than silently selecting a fallback parser.

## Phase 4 Proof

The test-only `backend-dummy` option exercises this boundary with a lazy local package. Its build
script rejects configuration unless the parent passes an explicit opt-in value. Consequently:

- `./build.sh test` proves the core graph succeeds without configuring the dummy dependency;
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
