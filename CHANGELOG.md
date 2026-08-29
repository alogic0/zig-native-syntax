# Changelog

This file records notable user-visible changes for each `zig-native-syntax`
release. Changes are grouped as Added, Changed, Deprecated, Removed, Fixed, or
Security when those categories apply. Breaking changes include migration notes
and follow the package [versioning policy](docs/versioning.md).

## [Unreleased]

## [0.1.0] - 2026-08-29

### Added

- Source-preserving capture primitives, checked half-open byte ranges, shared
  scopes, backend metadata, embedded-language composition, and safe HTML
  rendering.
- A generated configured registry containing 95 quality-verified languages:
  65 structural and 30 lexical backends.
- Package-owned canonical language names and common aliases, with escaped
  plain-text fallback for unknown or experimental languages.
- Selectable external Ziggy, Ziggy Schema, Scripty, HTML, XML, CSS, SuperHTML,
  and Markdown backends.
- Compatibility documentation, representative corpora, preview tools, seeded
  registry properties, allocation-failure checks, and non-gating performance
  baselines.
- CI gates for the pinned Zig version, formatting, exhaustive Debug tests,
  consolidated ReleaseSafe tests, and all optional backends together and in
  isolation.

### Fixed

- Valid UTF-8 captures are rejected when they split a code-point boundary,
  while malformed byte input retains its documented arbitrary-byte behavior.
- Bash and other byte-oriented scanners preserve complete Unicode scalars.
- Ziggy Schema parser allocations are contained so failed upstream AST
  construction cannot leak adapter-owned memory.

[Unreleased]: https://github.com/alogic0/zig-native-syntax/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/alogic0/zig-native-syntax/releases/tag/v0.1.0
