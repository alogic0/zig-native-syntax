# Versioning Policy

`zig-native-syntax` uses Semantic Versioning for its package releases. The
initial `0.1.0` release is intentionally pre-1.0, but compatibility changes are
still classified and documented rather than treating every pre-1.0 release as
unconstrained.

## Version Numbers

Before 1.0:

- `0.y.Z` patch releases contain compatible fixes, documentation, performance
  improvements, and classification refinements within an existing documented
  backend boundary;
- `0.Y.0` minor releases may contain breaking public changes, new public API,
  new verified backends, or materially expanded compatibility boundaries;
- every breaking change is identified in the changelog and migration notes.

Starting with 1.0, a breaking change increments the major version, compatible
public additions increment the minor version, and compatible fixes increment
the patch version.

## Public Compatibility Surface

The compatibility surface includes:

- public declarations, types, function signatures, errors, ownership rules,
  and build options;
- `Scope` tags and their `syntax-*` CSS class names and meanings;
- half-open byte ranges, source preservation, HTML escaping, UTF-8 boundary
  validation, and malformed-input fallback;
- canonical language names, aliases, `BackendKind`, `SupportLevel`, and the
  documented compatibility boundary of every verified backend;
- the declared minimum Zig version and package module names.

Removing or renaming any of these is breaking. Adding an enum tag or an error
is also source-breaking for Zig consumers with exhaustive switches or inferred
error handling, so it follows the breaking-change version rule.

Adding a verified backend or alias without changing an existing route is a
compatible feature. It still requires release notes because the complete
registry, generated support matrix, dependency graph, and linked size can
change. Retargeting an existing alias to a different language is breaking.

## Highlighting Behavior

A patch release may correct classification inside a backend's documented
boundary when it preserves source bytes, stable scope meanings, tolerant
malformed-input behavior, and the backend's support level. Exact captures are
not frozen when the previous result was demonstrably incorrect or less precise.

A materially broader language dialect, a changed compatibility boundary, or a
promotion from experimental to a verified support level is a minor feature.
Removing a verified construct, weakening source-safety guarantees, demoting a
verified backend, or changing an established scope's meaning is breaking.

Experimental backends are excluded from the normal configured registry and do
not carry behavioral compatibility guarantees. Their public shared API usage is
still governed by this policy.

## Parser And Toolchain Dependencies

Parser dependencies remain pinned to immutable revisions and package hashes. A
dependency-only update can be a patch when it preserves the adapter API,
declared Zig version, documented classifications, and build selection behavior.
An observable compatible syntax expansion is a minor feature.

An upgrade that removes a supported configuration, changes a public module or
build option, requires consumers to change code, or raises the minimum Zig
version is breaking. Dependency upgrades run the complete native tests, the
optional-backend matrix, consumer integration tests, and relevant size and
performance measurements before release.
