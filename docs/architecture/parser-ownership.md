# Parser And Tokenizer Ownership

## Decision

`zig-native-syntax` owns syntax-highlighting behavior, a stable classification model, adapters
from language-specific syntax APIs, and safe source-preserving rendering. It does not own or
duplicate a complete parser when an authoritative Zig parser or tokenizer is available from the
language implementation or another maintained package.

When no suitable Zig syntax API exists, a language backend may own a deliberately limited lexical
scanner. It should not grow into a complete parser unless parsing is independently required and
the project explicitly accepts responsibility for the language grammar.

## Date And Status

- Date: 2026-08-20
- Status: accepted

## Meaning Of Ownership

Parser ownership is an architectural and maintenance responsibility. It is separate from runtime
memory ownership.

The owner of a full parser is responsible for:

- the language grammar and lexical rules;
- AST structure and source locations;
- malformed-input recovery and diagnostics;
- conformance tests and language-version changes;
- compatibility for parser consumers.

The owner of a highlighting adapter is instead responsible for:

- invoking a supported parser or tokenizer API;
- translating tokens and relevant AST context into stable highlighting scopes;
- preserving original source byte offsets;
- producing useful partial classifications for malformed or incomplete snippets;
- adapting to upstream syntax API changes;
- testing the classifications expected from that backend.

## Responsibility Boundaries

```text
authoritative parser/tokenizer
             │
             ▼
language adapter owned by zig-native-syntax
             │
             ▼
classified source spans
             │
             ▼
shared source-preserving renderer
             │
             ▼
consumer CSS and document integration
```

The boundaries are:

| Concern | Owner |
| --- | --- |
| Language grammar and parser correctness | Language implementation or parser package |
| Mapping language syntax to stable scopes | `zig-native-syntax` language adapter |
| Span validation, source preservation, and HTML escaping | `zig-native-syntax` core |
| Fence aliases, unsupported-language policy, and CSS theme | Consumer such as Zine |
| Parser dependency versions used by a backend | `zig-native-syntax` package integration |

The first expected adapters are:

| Language family | Intended syntax authority | Highlighter responsibility |
| --- | --- | --- |
| Zig | `std.zig.Tokenizer` and `std.zig.Ast` | Map Zig tokens and selected AST context to scopes |
| HTML and XML | SuperHTML tokenizer and AST | Classify tags, attributes, values, comments, and text |
| SuperHTML | SuperHTML plus Scripty syntax APIs | Coordinate nested markup and expression spans |
| CSS | SuperHTML CSS tokenizer and AST | Classify lexical tokens and useful structural roles |
| Ziggy and Ziggy Schema | Ziggy tokenizers and ASTs | Map native token kinds while preserving source |
| Scripty | Scripty tokenizer or parser | Classify paths, calls, literals, and punctuation |

An adapter may depend only on a stable, independently consumable syntax package. It must not
introduce a dependency from this library back to one of its consumers.

## Source Preservation And Rendering

Existing parser renderers are not automatically suitable highlighting backends. They may reformat
input, omit invalid regions, generate links for a specific application, or emit HTML without the
escaping contract required here.

Adapters therefore produce classifications over the caller's original source. The shared renderer
escapes both classified spans and unclassified gaps. Parser-generated formatted source is not used
as a substitute for the original input.

Parser failures are not page-build failures by default. A backend should keep classifications that
are known to be safe and leave the remaining source unclassified so the renderer can emit it as
escaped plain text.

## Markdown Boundary

The Markdown parser is independently maintained as `zig-markdown-parser`. Both Zine and the optional
Markdown backend consume that package directly:

```text
Zine ────────────────→ zig-markdown-parser
  └→ zig-native-syntax ─→ zig-markdown-parser
```

This avoids a dependency path from `zig-native-syntax` back into Zine. The parser owns Markdown
syntax, immutable document traversal, and original-source byte spans. The highlighting adapter owns
the mapping from parser nodes to language-neutral scopes. Zine retains SuperMD directives, page
semantics, fence aliases, and fallback policy.

The adapter consumes only the parser's public read-only traversal API. It does not copy parser
storage, use Zine's compatibility AST, or add highlighting concerns to the parser package.

The same rule applies when another useful parser is vendored only inside a consumer: use a stable
upstream package API, keep the adapter in the consumer temporarily, or extract the parser under a
separate ownership boundary.

## Languages Without A Suitable Parser

Syntax coloring often needs only lexical classification. For a language without a maintained Zig
parser, a backend may implement a source scanner that recognizes constructs such as comments,
strings, numbers, keywords, identifiers, and punctuation.

Such a backend owns only its documented highlighting subset. It should remain tolerant of syntax it
does not understand and must not present itself as a validator or compiler-quality parser. Contextual
categories such as function, type, field, or attribute can be added when they are reliable without
turning the scanner into an implicit full parser.

## Runtime Memory Ownership

- The caller owns the source bytes for the duration of highlighting.
- Spans store byte offsets and classifications; they do not own source copies.
- A backend owns and releases temporary parser or scanner allocations before returning unless an
  explicitly documented result object transfers that ownership.
- Returned data must not reference temporary parser storage.
- The caller owns the output writer and its backing storage.

These rules keep source lifetimes visible and allow adapters to use allocation-free tokenizers where
available.

## Consequences

- Existing language implementations remain the source of truth for their grammars.
- The project avoids maintaining duplicate parsers that can drift from their languages.
- Parser API changes can require adapter updates and pinned dependency changes.
- Lexical-only backends can be less semantically precise than Tree-sitter queries, but their supported
  behavior is explicit and independently testable.
- A complete native highlighting set can grow language by language without forcing every consumer to
  compile every backend.

## Revisit When

Revisit this decision if a required highlighting feature cannot be implemented from existing syntax
APIs or a bounded scanner, or if a parser developed here becomes independently useful enough to need
its own package, grammar policy, and release lifecycle.
