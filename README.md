# zig-native-syntax

`zig-native-syntax` is an experimental, source-preserving syntax-highlighting library written
in Zig. It is intended to classify source code with native Zig tokenizers and parsers, then
render those classifications safely without depending on Tree-sitter.

The first consumer is the Zine static site generator. This repository is intentionally
independent so that its highlighting adapters, tests, and compatibility policy can be reused by
other Zig projects.

## Status

The project contains the initial classification API, source-preserving HTML renderer, Zig, Bash,
Rust, JSON, Diff, TOML, Dockerfile, Python, SQL, C, JavaScript, TypeScript, and YAML backends, and optional Ziggy document, Ziggy Schema,
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
- [YAML highlighting compatibility](docs/compatibility/yaml.md) defines line and block-scalar
  recovery and the schema-resolution boundary.
- [HCL highlighting compatibility](docs/compatibility/hcl.md) defines expression, template, and
  heredoc lexical coverage and the evaluation boundary.
- [Make highlighting compatibility](docs/compatibility/make.md) defines line-oriented build rules
  and the embedded-recipe boundary.
- [CMake highlighting compatibility](docs/compatibility/cmake.md) defines command-oriented lexical
  coverage and the generator/evaluation boundary.
- [Roadmap languages 25–42 compatibility](docs/compatibility/roadmap-25-42.md) defines the lexical
  and embedded-language boundaries for Java through Protocol Buffers.
- [Roadmap languages 43–74 compatibility](docs/compatibility/roadmap-43-74.md) defines bounded
  format and programming-language coverage from KDL through Nim.
- [Roadmap languages 75–83 compatibility](docs/compatibility/roadmap-75-83.md) defines bounded
  language coverage from D through Hare.
- [Roadmap languages 84–88 compatibility](docs/compatibility/roadmap-84-88.md) defines the final
  lexical backends from Agda through generic comment tags.

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
./build.sh render-yaml tests/corpus/yaml/complete.yaml > /tmp/yaml.html
./build.sh render-hcl tests/corpus/hcl/complete.hcl > /tmp/hcl.html
./build.sh render-make tests/corpus/make/complete.mk > /tmp/make.html
./build.sh render-cmake tests/corpus/cmake/complete.cmake > /tmp/cmake.html
./build.sh render-java tests/corpus/java/complete.java > /tmp/java.html
./build.sh render-c-sharp tests/corpus/c_sharp/complete.cs > /tmp/c-sharp.html
./build.sh render-cpp tests/corpus/cpp/complete.cpp > /tmp/cpp.html
./build.sh render-go tests/corpus/go/complete.go > /tmp/go.html
./build.sh render-powershell tests/corpus/powershell/complete.ps1 > /tmp/powershell.html
./build.sh render-php tests/corpus/php/complete.php > /tmp/php.html
./build.sh render-lua tests/corpus/lua/complete.lua > /tmp/lua.html
./build.sh render-kotlin tests/corpus/kotlin/complete.kt > /tmp/kotlin.html
./build.sh render-ruby tests/corpus/ruby/complete.rb > /tmp/ruby.html
./build.sh render-swift tests/corpus/swift/complete.swift > /tmp/swift.html
./build.sh render-asm tests/corpus/assembly/complete.s > /tmp/asm.html
./build.sh render-nasm tests/corpus/nasm/complete.nasm > /tmp/nasm.html
./build.sh render-objc tests/corpus/objc/complete.m > /tmp/objc.html
./build.sh render-vue tests/corpus/vue/complete.vue > /tmp/vue.html
./build.sh render-astro tests/corpus/astro/complete.astro > /tmp/astro.html
./build.sh render-jsdoc tests/corpus/jsdoc/complete.jsdoc > /tmp/jsdoc.html
./build.sh render-regex tests/corpus/regex/complete.regex > /tmp/regex.html
./build.sh render-proto tests/corpus/proto/complete.proto > /tmp/proto.html
./build.sh render-kdl tests/corpus/kdl/complete.txt > /tmp/kdl.html
./build.sh render-nim tests/corpus/nim/complete.txt > /tmp/nim.html
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
