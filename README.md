# zig-native-syntax

`zig-native-syntax` is an experimental, source-preserving syntax-highlighting library written
in Zig. It is intended to classify source code with native Zig tokenizers and parsers, then
render those classifications safely without depending on Tree-sitter.

The first consumer will be the Zine static site generator. This repository is intentionally
independent so that its highlighting adapters, tests, and compatibility policy can be reused by
other Zig projects.

## Status

The project currently contains only the initial library and span model. No language backend or
HTML renderer has been implemented yet.

## Design constraints

- Preserve the input source byte-for-byte in rendered output.
- Escape untrusted source before emitting HTML.
- Continue highlighting valid regions around malformed or incomplete input.
- Keep language backends selectable so consumers only compile the languages they use.
- Adapt existing native tokenizers and parsers where suitable instead of duplicating them.

## Architecture

- [Language backend contract](docs/architecture/backend-contract.md) defines backend metadata,
  capture reporting, errors, and optional registration.
- [Capture and range model](docs/architecture/capture-model.md) defines source offsets, validation,
  overlap, and memory ownership.
- [Classification model](docs/architecture/classification-model.md) defines the language-neutral
  scopes and their stable CSS class names.
- [Parser and tokenizer ownership](docs/architecture/parser-ownership.md) defines the boundary
  between language implementations, highlighting adapters, the shared renderer, and consumers.
- [Development plan](docs/plans/development-plan.md) defines the phased implementation and
  integration sequence.

## Development

The project currently tracks the Zig version used by Zine:

```sh
./build.sh test
```

The [experimental API guide](docs/api.md) shows the current public classification interface.
