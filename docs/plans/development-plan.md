# Development Plan

## Objective

Build a reusable Zig library that converts source code into deterministic, safely escaped,
source-preserving HTML using native Zig tokenizers, parsers, and bounded lexical scanners. Use the
library to let Zine replace Tree-sitter deliberately, without making this package responsible for
complete language grammars or consumer-specific presentation.

The ownership rules in [Parser And Tokenizer Ownership](../architecture/parser-ownership.md) are
authoritative for every phase of this plan.

## Current Baseline

- [x] Independent `zig-native-syntax` repository created.
- [x] Zig `0.17.0-dev.1756+613c03321` recorded as the minimum and local development version.
- [x] Initial `Scope` and `Span` model created.
- [x] Parser, adapter, renderer, and consumer ownership boundaries documented.
- [ ] Public highlighting API finalized.
- [ ] Source-preserving HTML renderer implemented.
- [ ] First language backend implemented.
- [ ] Zine integration started.

The existing `Scope` and `Span` declarations are provisional. Phase 1 may replace them before any
compatibility promise is made.

## Scope

The project owns:

- stable syntax classifications;
- source-range and capture validation;
- language adapters;
- bounded lexical scanners where no suitable parser exists;
- source-preserving HTML escaping and rendering;
- backend selection facilities and capability reporting;
- correctness, malformed-input, and performance tests.

Consumers own:

- filename and fence-language aliases;
- CSS themes and presentation;
- unsupported-language policy;
- document structure around highlighted output;
- application-specific features such as Zine's console prompt highlighting.

## Non-Goals

- Implementing compiler-quality parsers solely for highlighting.
- Validating, formatting, or rewriting source code.
- Producing an AST for consumers.
- Owning a CSS theme.
- Reproducing Tree-sitter capture names or HTML byte-for-byte.
- Zig documentation symbol links or declaration navigation.
- Browser-side or incremental editor highlighting in the initial releases.
- Supporting every language bundled by Zine's current Tree-sitter dependency before the library is
  useful.

## Initial Language Targets

| Tier | Languages | Strategy |
| --- | --- | --- |
| Core | Plain text, Zig | Escaped fallback plus Zig standard-library syntax APIs |
| Native package adapters | Ziggy, Ziggy Schema, Scripty | Maintained upstream tokenizers or parsers |
| Markup and style adapters | HTML, XML, CSS | Maintained SuperHTML syntax APIs |
| Composed adapter | SuperHTML | HTML structure plus nested Scripty classifications |
| Boundary decision | Markdown/SuperMD | Keep consumer-owned, extract parser, or add bounded scanner |
| Compatibility scanners | Shell/Bash, Rust | Purpose-built lexical scanners after their supported subsets are documented |
| Deferred | JavaScript and remaining Tree-sitter languages | Add according to measured consumer demand and suitable syntax APIs |

Shell/Bash and Rust are prioritized among languages without existing project parsers because Zine's
current documentation and rendering fixtures exercise them. This priority does not imply a promise
to implement their complete grammars.

## Working Rules

- Each numbered slice below is intended to be independently reviewable and committed after its own
  verification gates pass.
- Use `./build.sh` for project builds and tests.
- Run `zig fmt` on every changed Zig or build file.
- Keep tests next to focused implementation where practical; use corpus and integration directories
  for cross-module behavior.
- Do not add machine-specific absolute paths to source or documentation.
- Pin external dependencies by URL and hash only after a backend proves that the dependency API is
  suitable.
- Treat malformed source as data to highlight partially, not as a fatal validation error.
- Keep the core usable without optional external parser dependencies.

## Phase 1: Stabilize The Core Contract

Goal: define the smallest public model that all native and lexical backends can implement.

### Slice 1.1: Classification taxonomy

Status: complete.

- Audit the classifications required by Zig, Ziggy, HTML, CSS, Scripty, Rust, and shell samples.
- Decide whether `Scope` is a flat enum, a primary category plus modifiers, or a hierarchical value.
- Define stable CSS class names independently of Tree-sitter capture names.
- Reserve a documented extension mechanism only if concrete backend requirements need one.

Acceptance criteria:

- Every initial language corpus can be represented without language-specific strings in the core.
- Scope-to-class conversion cannot inject arbitrary HTML or CSS class content.

### Slice 1.2: Capture and range invariants

Status: complete.

- Define byte-offset types and maximum source-size behavior.
- Decide how identical, nested, adjacent, and crossing captures are represented.
- Specify deterministic precedence when multiple classifications cover the same bytes.
- Reject out-of-range and structurally invalid captures before rendering.

Acceptance criteria:

- Unit tests cover empty, adjacent, identical, nested, crossing, unsorted, and out-of-range spans.
- No returned span borrows temporary parser storage.

### Slice 1.3: Backend interface

- Define the backend contract for borrowed source, allocator use, output captures, and errors.
- Separate unsupported-language and resource failures from malformed source.
- Decide whether backends stream captures or return an owned normalized result.
- Define capability metadata without adopting consumer-specific aliases.

Acceptance criteria:

- A test backend can classify input without importing the HTML renderer.
- Allocation and ownership rules are explicit at every public call boundary.

### Slice 1.4: Public API tests and documentation

- Add compile-time API examples.
- Add tests using `std.testing.allocator` where allocations occur.
- Document which declarations are stable and which remain experimental.

Phase gate:

- `./build.sh test` passes with the pinned compiler.
- The public contract supports the renderer and Zig backend without a language-specific exception.

## Phase 2: Implement Source-Preserving Rendering

Goal: render classified source securely while retaining all source bytes and deterministic class
boundaries.

### Slice 2.1: Escaped plain-text renderer

- Implement HTML text escaping for `&`, `<`, `>`, and any additional characters required by the
  selected output context.
- Write directly to `std.Io.Writer` without copying unchanged source unnecessarily.
- Establish the escaped plain-text fallback as a supported API.

### Slice 2.2: Classified span renderer

- Render validated classifications as spans with library-controlled class names.
- Preserve unclassified gaps and trailing source.
- Produce deterministic nesting or normalized segments for overlapping captures.

### Slice 2.3: Security and preservation properties

- Test empty input, all escapable bytes, invalid UTF-8, multiline input, and embedded tag-shaped
  strings.
- Add a test helper that removes generated markup, decodes entities, and verifies recovery of the
  original source bytes.
- Test that neither source text nor backend-provided metadata can create attributes or elements.

### Slice 2.4: Failure behavior

- Verify writer failures propagate without hidden allocations or partial-state reuse.
- Verify malformed capture sets fail predictably or normalize according to the Phase 1 contract.
- Add randomized range tests for renderer bounds safety.

Phase gate:

- Every renderer test is independent of a language parser.
- Source-preservation and injection tests pass under Debug and ReleaseSafe modes.

## Phase 3: Implement The Zig Backend

Goal: prove the architecture using the pinned Zig standard library as the syntax authority.

### Slice 3.1: Lexical Zig highlighting

- Use `std.zig.Tokenizer` to classify keywords, builtins, strings, character literals, comments,
  numbers, primitive values, identifiers, and punctuation.
- Preserve whitespace and invalid-token regions through the shared renderer.
- Base mappings on the pinned standard-library token tags rather than recalled APIs.

### Slice 3.2: Optional AST context

- Parse with `std.zig.Ast` only for classifications that materially improve output, such as function
  declarations or type context.
- Retain lexical highlighting when the AST reports syntax errors.
- Do not implement documentation links or declaration resolution.

### Slice 3.3: Zig corpus and parity review

- Add complete declarations, expressions, comments, multiline strings, builtins, malformed snippets,
  and incomplete snippets.
- Compare representative output visually and structurally with Zig's standard documentation renderer
  and Zine's current Tree-sitter output.
- Document intentional classification differences.

Phase gate:

- Zig highlighting is source-preserving and safe for malformed snippets.
- The Zig backend has no C dependency and no Tree-sitter dependency.

## Phase 4: Perform The First Zine Integration Spike

Goal: validate the public API in its first real consumer before adding external parser dependencies.

### Slice 4.1: Local dependency wiring

- Add `zig-native-syntax` as a local path dependency on Zine's experiment branch.
- Route canonical `zig` code blocks through the native backend.
- Keep Tree-sitter as the fallback for every other currently supported language.

### Slice 4.2: CSS and snapshot adaptation

- Map stable library classes into Zine's starter highlight stylesheet.
- Update only Zig snapshots whose markup changes intentionally.
- Verify source escaping for fenced blocks, code directives, and string highlighting helpers.

### Slice 4.3: Integration evidence

- Compare build time, executable size, peak allocations, and representative output with the current
  Tree-sitter path.
- Record API friction in this plan or the relevant architecture document before expanding backends.
- Revise Phase 1 APIs while compatibility is still experimental if the integration exposes a poor
  ownership or lifetime boundary.

Phase gate:

- Zine renders Zig natively and all other languages through the unchanged fallback.
- Zine's focused rendering and workflow tests pass on the local architecture.

## Phase 5: Make External Backends Selectable

Goal: add parser-backed languages without forcing unused parser packages into every consumer graph.

### Slice 5.1: Dependency and module layout

- Prototype lazy Zig package dependencies and backend build options.
- Decide whether optional languages are exposed as separate modules or one configured root module.
- Verify a core-only consumer does not fetch, compile, or link optional parser dependencies.

### Slice 5.2: Backend conformance suite

- Create shared tests that every backend runs for empty, valid, malformed, multiline, escapable, and
  invalid-UTF-8 input where the language permits it.
- Require deterministic captures and source recovery for all backends.
- Provide backend-specific corpus hooks without putting grammar rules in the core.

Phase gate:

- A dummy optional backend proves selection behavior.
- The core-only build remains dependency-free beyond Zig's standard library.

## Phase 6: Add Ziggy And Scripty Families

Goal: implement the small data and expression languages already used by Zine and SuperHTML.

### Slice 6.1: Ziggy adapter

- Pin a compatible Ziggy package.
- Consume its tokenizer or AST locations while retaining the original source.
- Cover comments, strings, numbers, booleans, nulls, enum cases, punctuation, and malformed data.

### Slice 6.2: Ziggy Schema adapter

- Use the schema tokenizer and AST as the syntax authority.
- Classify schema declarations, identifiers, types, literals, comments, and punctuation.
- Keep schema scopes within the common taxonomy unless evidence requires a documented extension.

### Slice 6.3: Scripty adapter

- Prefer an exported tokenizer API; use parser node locations only if they provide sufficient source
  coverage.
- If the required tokenizer is private, propose the smallest upstream export rather than copying it.
- Cover paths, calls, literals, booleans, punctuation, truncation, and invalid expressions.

Phase gate:

- Each backend can be enabled independently.
- Parser errors leave safely escaped, readable output rather than failing rendering.

## Phase 7: Add HTML, XML, And CSS

Goal: consume maintained SuperHTML syntax APIs for markup and stylesheet highlighting.

### Slice 7.1: SuperHTML dependency boundary

- Determine whether a stable independently consumable upstream package exposes the required HTML and
  CSS tokenizers.
- Do not depend on a copy vendored only inside Zine.
- Pin the smallest suitable package surface and record the compatibility version.

### Slice 7.2: HTML and XML adapter

- Classify tag delimiters, tag names, attribute names, attribute values, comments, doctypes, entities,
  and text where useful.
- Respect HTML and XML tokenizer-mode differences.
- Treat script and style contents as unclassified escaped text until nested backends are explicitly
  composed.

### Slice 7.3: CSS adapter

- Classify comments, identifiers, functions, at-keywords, hashes, strings, URLs, numbers, dimensions,
  delimiters, and structural punctuation.
- Add AST context for selectors and properties only where reliable and useful.
- Preserve malformed strings, URLs, and declarations.

Phase gate:

- HTML, XML, and CSS can be enabled without Ziggy or Scripty.
- Corpus tests include hostile HTML-shaped source and incomplete markup.

## Phase 8: Add SuperHTML Composition

Goal: combine markup and Scripty classifications without duplicating either parser.

### Slice 8.1: Embedded-region contract

- Define how a parent backend delegates a byte range to a nested backend.
- Translate nested offsets safely into the original source coordinate space.
- Specify precedence at language boundaries and for overlapping parent classifications.

### Slice 8.2: SuperHTML adapter

- Use SuperHTML syntax information to locate directives and embedded Scripty expressions.
- Merge HTML and Scripty classifications through the shared normalization path.
- Recover locally when either the markup or expression parser reports an error.

### Slice 8.3: Composition corpus

- Cover nested templates, quoted expressions, malformed attributes, multiline expressions, escaped
  delimiters, and adjacent embedded regions.
- Add randomized offset-translation tests.

Phase gate:

- SuperHTML output preserves the entire original source.
- Nested failures cannot create invalid ranges or unsafe HTML.

## Phase 9: Resolve Markdown Ownership

Goal: support Markdown source highlighting without creating a dependency cycle with Zine.

### Slice 9.1: Requirements audit

- Measure whether Zine or another intended consumer actually needs highlighted Markdown source.
- Define required constructs and whether embedded HTML or fenced-language composition is in scope.
- Compare a bounded scanner with extracting the existing Markdown parser into an independent package.

### Slice 9.2: Implement the selected boundary

- Keep the adapter in Zine if it depends on Zine-owned parser internals; or
- consume an independently extracted parser package; or
- implement and clearly document a lexical Markdown subset.

Phase gate:

- No dependency path leads from `zig-native-syntax` back into Zine.
- The selected behavior and limitations are documented before it is advertised as supported.

## Phase 10: Add Compatibility Scanners By Demand

Goal: preserve the most valuable non-native language coverage without building hidden full parsers.

### Slice 10.1: Usage and compatibility contract

- Audit Zine fixtures, example sites, and known consumer language labels.
- Define the language set required before Tree-sitter can be removed from Zine.
- Specify whether unsupported languages are rejected, rendered as escaped plain text, or delegated to
  an optional fallback.

### Slice 10.2: Shell/Bash scanner

- Document the supported shell dialect and lexical subset.
- Cover comments, quoting forms, variables, substitutions, operators, keywords, and heredocs according
  to that subset.
- Include incomplete quotes, substitutions, and heredocs in the corpus.

### Slice 10.3: Rust scanner

- Document the supported Rust lexical subset.
- Cover comments, raw and byte strings, character literals versus lifetimes, numbers, attributes,
  keywords, identifiers, macros, and punctuation.
- Include nested block comments and incomplete raw strings.

### Slice 10.4: Prioritize further languages

- Rank candidates using real consumer demand, availability of maintained Zig syntax APIs, implementation
  complexity, binary-size cost, and security risk.
- Add one backend per independently reviewable slice.
- Do not treat matching the old count of Tree-sitter grammars as a release criterion by itself.

Phase gate:

- Every owned scanner states what it recognizes and what remains plain text.
- Scanner tests do not claim syntax validation or full grammar conformance.

## Phase 11: Complete The Zine Migration

Goal: make native highlighting operationally selectable, then remove Tree-sitter only after explicit
compatibility approval.

### Slice 11.1: Backend selection

- Add a temporary Zine selection mode for native-first with Tree-sitter fallback, native-only, and
  current Tree-sitter behavior.
- Keep unknown-language diagnostics consistent with the selected mode.
- Ensure disabling highlighting still emits safely escaped plain text.

### Slice 11.2: Native coverage conversion

- Convert Zine fixtures language by language.
- Update snapshots for intentional class and span changes.
- Verify code fences, code directives, imported snippets, and string helper highlighting.

### Slice 11.3: Tree-sitter removal decision

- Review supported-language differences and obtain explicit compatibility approval.
- Verify local-architecture builds and tests without `flow-syntax`, `tree_sitter`, or `treez` imports.
- Remove those dependencies and obsolete build options only after the native-only gate passes.
- Record executable-size, dependency-size, build-time, and behavior changes.

Phase gate:

- Zine's accepted supported-language set has native backends or documented plain-text behavior.
- Zine has no runtime, build, package-manifest, or validation dependency on Tree-sitter.
- Zine's required tests pass locally; platform-specific and release validation remains in CI rather
  than requiring all targets to be built locally.

## Phase 12: Harden And Release The Package

Goal: turn the experiment into a versioned dependency suitable for Zine and other consumers.

### Slice 12.1: Public documentation

- Add API examples for core-only, selected backends, custom rendering, and plain-text fallback.
- Publish the supported-language and supported-subset matrix.
- Document scope class stability, error behavior, allocation behavior, and dependency selection.

### Slice 12.2: Quality gates

- Add formatting, Debug, and ReleaseSafe tests to CI using the declared Zig version.
- Run corpus, randomized range, escaping, allocation, and integration tests.
- Add representative benchmarks and record baselines without imposing arbitrary thresholds.

### Slice 12.3: Package policy

- Choose and document the project license before publication.
- Define semantic-versioning expectations for scope names, backend behavior, and parser dependency
  upgrades.
- Create a changelog or release-note policy.

### Slice 12.4: Zine dependency pin

- Publish the repository at its intended remote.
- Replace Zine's experimental local path with a pinned Git revision and Zig package hash.
- Run Zine's accepted local verification gates and GitHub CI before merging the experiment branch.

Phase gate:

- A fresh consumer can fetch the package and enable only selected backends.
- Zine consumes a reproducible pinned revision rather than a machine-local path.

## Cross-Cutting Test Matrix

Every backend should cover the applicable rows:

| Category | Required evidence |
| --- | --- |
| Empty and whitespace | No unnecessary markup; source preserved |
| Representative valid source | Expected stable classifications |
| Incomplete source | Useful partial highlighting; no fatal syntax error |
| Malformed source | Escaped readable output; no invalid ranges |
| Escapable source | No HTML injection; source recoverable after entity decoding |
| Multiline constructs | Correct offsets across all newline forms supported by the backend |
| Invalid UTF-8 | Defined behavior without out-of-bounds access |
| Allocation failure | Clean error propagation and no leaks where allocation is used |
| Determinism | Identical source and configuration produce identical output |
| Backend disabled | No dependency import and no backend code required by the core build |

## Success Criteria

The project is successful when:

- classification and rendering are separate public responsibilities;
- the renderer is source-preserving and safe for untrusted input;
- malformed snippets degrade to partial highlighting or escaped plain text;
- existing parser projects remain the grammar authorities;
- core-only consumers do not inherit optional parser dependencies;
- Zine can remove Tree-sitter after explicitly accepting its new language-support contract;
- the package is reproducibly pinned and tested with Zine's declared Zig version.

## Principal Risks

| Risk | Mitigation |
| --- | --- |
| Scope API freezes before real backends exercise it | Integrate Zig with Zine before adding many adapters |
| Parser APIs expose ASTs but insufficient lexical ranges | Prefer tokenizers; request small upstream exports rather than copying code |
| Overlapping captures produce invalid HTML | Define and property-test normalization before language work |
| Parser errors discard useful tokens | Keep lexical paths and escaped fallback independent of successful parsing |
| Optional backends still pull large dependency graphs | Verify dependency selection with a core-only consumer test |
| Native output silently loses semantic detail | Maintain corpus comparisons and document intentional differences |
| Owned scanners become incomplete parsers | Publish bounded lexical contracts and resist validation features |
| Consumer aliases leak into the library API | Keep canonical backend identifiers separate from Zine policy |
| Machine-local integration becomes permanent | Require a pinned Git dependency before release or merge |
