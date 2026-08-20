# zig-native-syntax

`zig-native-syntax` is an experimental, source-preserving syntax-highlighting library written
in Zig. It is intended to classify source code with native Zig tokenizers and parsers, then
render those classifications safely without depending on Tree-sitter.

The first consumer will be the Zine static site generator. This repository is intentionally
independent so that its highlighting adapters, tests, and compatibility policy can be reused by
other Zig projects.

## Status

The project contains the initial classification API, source-preserving HTML renderer, and a Zig
backend with lexical classification plus recovering AST context. Additional language adapters and
Zine integration remain experimental work.

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
- [Optional backend selection](docs/architecture/backend-selection.md) defines how external parser
  adapters remain independently selectable without changing the core module.
- [Development plan](docs/plans/development-plan.md) defines the phased implementation and
  integration sequence.
- [Zig highlighting compatibility](docs/compatibility/zig.md) records corpus coverage and intentional
  differences from Zig's documentation renderer and Zine's Tree-sitter path.

## Development

The project currently tracks the Zig version used by Zine:

```sh
./build.sh test
```

Render a Zig source file as an HTML fragment for manual inspection:

```sh
./build.sh render-zig tests/corpus/zig/complete.zig > /tmp/complete.html
```

Add `--page` to emit a complete HTML document with a built-in development theme:

```sh
./build.sh render-zig --page tests/corpus/zig/complete.zig > /tmp/complete.html
```

The command writes only to standard output. Fragment mode emits escaped source and `syntax-*` spans;
page mode wraps the same rendering in a preview document suitable for opening in a browser. Its
development theme is maintained in `tools/render_zig.css` and embedded into the generated page.

The [experimental API guide](docs/api.md) shows the current public classification interface.
