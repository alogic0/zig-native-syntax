# zig-native-syntax

`zig-native-syntax` is an experimental, source-preserving syntax-highlighting library written
in Zig. It is intended to classify source code with native Zig tokenizers and parsers, then
render those classifications safely without depending on Tree-sitter.

The first consumer is the Zine static site generator. This repository is intentionally
independent so that its highlighting adapters, tests, and compatibility policy can be reused by
other Zig projects.

## Status

The project contains the initial classification API, source-preserving HTML renderer, Zig, Bash,
Rust, JSON, Diff, TOML, Dockerfile, Python, SQL, C, JavaScript, and TypeScript backends, and optional Ziggy document, Ziggy Schema,
Scripty, HTML, XML, CSS, composed SuperHTML, and parser-backed Markdown backends. Additional
language adapters and Zine integration remain experimental work.

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
- [Embedded language composition](docs/architecture/composition.md) defines nested backend offset
  translation and overlapping-scope behavior.
- [Development plan](docs/plans/development-plan.md) defines the phased implementation and
  integration sequence.
- [Zig highlighting compatibility](docs/compatibility/zig.md) records corpus coverage and intentional
  differences from Zig's documentation renderer and Zine's Tree-sitter path.
- [Ziggy highlighting compatibility](docs/compatibility/ziggy.md) records the optional tokenizer
  adapter's classifications and recovery boundary.
- [Ziggy Schema highlighting compatibility](docs/compatibility/ziggy-schema.md) records the optional
  tokenizer and AST adapter's classifications and recovery boundary.
- [Scripty highlighting compatibility](docs/compatibility/scripty.md) records the parser-backed
  adapter, bounded recovery scanner, and proposed upstream tokenizer export.
- [SuperHTML syntax API compatibility](docs/compatibility/superhtml.md) records the upstream
  dependency boundary and the HTML, XML, and CSS adapter behavior.
- [Markdown highlighting compatibility](docs/compatibility/markdown.md) records the standalone
  parser boundary, classifications, and deferred composition behavior.
- [Language demand and fallback policy](docs/compatibility/language-demand.md) records the audited
  Zine language labels, migration requirements, and unsupported-language behavior.
- [Bash highlighting compatibility](docs/compatibility/bash.md) defines the owned shell lexical
  subset and the constructs intentionally left as plain text.
- [Rust highlighting compatibility](docs/compatibility/rust.md) defines the owned Rust lexical
  subset, recovery rules, and grammar-dependent limitations.
- [JSON highlighting compatibility](docs/compatibility/json.md) defines the source-offset scanner,
  standard-library validation oracle, recovery rules, and JSON5 boundary.
- [Diff highlighting compatibility](docs/compatibility/diff.md) defines the line-oriented patch
  structure and embedded-payload boundary.
- [TOML highlighting compatibility](docs/compatibility/toml.md) defines scalar and key coverage and
  the boundary between lexical highlighting and TOML validation.
- [Dockerfile highlighting compatibility](docs/compatibility/dockerfile.md) defines Dockerfile
  structure coverage and the embedded shell boundary.
- [Python highlighting compatibility](docs/compatibility/python.md) defines tokenizer-style
  coverage and the f-string and indentation boundary.
- [SQL highlighting compatibility](docs/compatibility/sql.md) defines the common lexical subset and
  dialect boundary.
- [C highlighting compatibility](docs/compatibility/c.md) defines lexical coverage and explains why
  highlighting does not own an Aro compiler pipeline.
- [JavaScript highlighting compatibility](docs/compatibility/javascript.md) defines tokenizer-style
  coverage and regex, JSX, and template-expression boundaries.
- [TypeScript highlighting compatibility](docs/compatibility/typescript.md) defines the shared
  JavaScript scanner boundary and TypeScript-specific lexical additions.

## Development

The project currently tracks the Zig version used by Zine:

```sh
./build.sh test
```

Render source files as HTML fragments for manual inspection:

```sh
./build.sh render-zig tests/corpus/zig/complete.zig > /tmp/complete.html
./build.sh render-bash tests/corpus/bash/complete.sh > /tmp/bash.html
./build.sh render-rust tests/corpus/rust/complete.rs > /tmp/rust.html
./build.sh render-json tests/corpus/json/complete.json > /tmp/json.html
./build.sh render-diff tests/corpus/diff/complete.diff > /tmp/diff.html
./build.sh render-toml tests/corpus/toml/complete.toml > /tmp/toml.html
./build.sh render-dockerfile tests/corpus/dockerfile/complete.Dockerfile > /tmp/dockerfile.html
./build.sh render-python tests/corpus/python/complete.py > /tmp/python.html
./build.sh render-sql tests/corpus/sql/complete.sql > /tmp/sql.html
./build.sh render-c tests/corpus/c/complete.c > /tmp/c.html
./build.sh render-javascript tests/corpus/javascript/complete.js > /tmp/javascript.html
./build.sh render-typescript tests/corpus/typescript/complete.ts > /tmp/typescript.html
./build.sh render-ziggy tests/corpus/ziggy/complete.ziggy > /tmp/ziggy.html
./build.sh render-ziggy-schema tests/corpus/ziggy-schema/complete.ziggy-schema > /tmp/schema.html
./build.sh render-scripty tests/corpus/scripty/complete.scripty > /tmp/scripty.html
./build.sh render-html tests/corpus/html/complete.html > /tmp/html.html
./build.sh render-xml tests/corpus/xml/complete.xml > /tmp/xml.html
./build.sh render-css tests/corpus/css/complete.css > /tmp/css.html
./build.sh render-superhtml tests/corpus/superhtml/complete.shtml > /tmp/superhtml.html
./build.sh render-markdown tests/corpus/markdown/complete.md > /tmp/markdown.html
```

Add `--page` to any preview command to emit a complete HTML document with a built-in development
theme:

```sh
./build.sh render-ziggy --page tests/corpus/ziggy/complete.ziggy > /tmp/ziggy.html
```

The command writes only to standard output. Fragment mode emits escaped source and `syntax-*` spans;
page mode wraps the same rendering in a preview document suitable for opening in a browser. The
shared development theme is maintained in `tools/render_zig.css` and embedded into each generated
page. Optional-language preview commands enable only their matching backend automatically.

The [experimental API guide](docs/api.md) shows the current public classification interface.
