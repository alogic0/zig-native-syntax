# Zig-Style Parser Architecture Plan

## Status

Implemented on 2026-08-22. The shared syntax core and the first JavaScript/TypeScript parser are in
place, and both language backends now derive contextual scopes from syntax nodes. Bash subsequently
migrated to the same architecture for commands, assignments, redirections, function definitions,
arguments, and loop variables. A third pilot migrated Rust for declarations, parameters, bindings,
fields, calls, members, type references, modules, constants, and enum variants.

## Goal

Give native language backends a common Zig-style syntax pipeline without pretending that one
grammar can parse every language:

```text
source -> language tokenizer -> lossless token table -> tolerant language parser
       -> compact syntax tree -> highlighting adapter -> captures
```

The shared layer owns source locations, token and node storage, diagnostics, and parser cursor
mechanics. Each language continues to own its token tags, node tags, grammar, recovery rules, and
mapping to the stable highlighting scopes.

## Why This Is Incremental

A parser is useful only when it knows a language grammar. Wrapping the existing scanners in a tree
after they emit captures would add storage without improving classification. This plan therefore
introduces the common representation once, then migrates languages only when a real tolerant parser
can replace highlighting heuristics.

The first migration is JavaScript and TypeScript. They currently share a scanner, have high consumer
demand, and contain contextual distinctions that demonstrate the value of parsing: declarations,
parameters, calls, member access, and TypeScript type declarations. TypeScript remains a mode of the
same syntax package rather than becoming a fork.

## Shared Syntax Core

The core will provide generic, language-parameterized storage for:

- tokens with tags and half-open source byte ranges;
- compact nodes with tags, token ranges, and a main token;
- diagnostics attached to source positions;
- a token cursor with bounded lookahead and explicit advancement;
- ownership-safe construction and deinitialization.

The core will not contain keyword tables, operator rules, grammar productions, scope mappings, or a
universal parser generator. Those concerns differ by language and remain beside each language parser.

## JavaScript And TypeScript Parser Boundary

The first parser is deliberately a highlighting parser, not an ECMAScript validator. It will:

- preserve every token's original source byte range;
- tokenize comments, literals, template strings, identifiers, keywords, operators, and punctuation;
- recognize variable, function, class, interface, type-alias, and enum declarations;
- recognize parameter bindings, call expressions, and member access;
- recover at statement and balanced-delimiter boundaries;
- return a useful partial tree for incomplete snippets.

It will not perform module resolution, binding resolution, automatic-semicolon-insertion validation,
type checking, JSX parsing, or regular-expression validation. Ambiguous slash tokens remain operators
until a later expression-context tokenizer adds regular-expression literals.

## Commit Slices

1. [x] Document this architecture and migration policy.
2. [x] Add the shared syntax core with focused ownership, cursor, and recovery tests.
3. [x] Add the JavaScript/TypeScript tokenizer and structural parser with parser-level tests.
4. [x] Replace the two direct scanners with adapters over tokens and syntax nodes; update metadata and
   conformance expectations.
5. [x] Record compatibility boundaries and run the complete repository test gate.

Every slice must compile and pass its focused tests before it is committed. The final slice must pass
`./build.sh test` while leaving unrelated working-tree changes untouched.

## Later Migrations

After the first parser establishes the API, migrate languages according to observed classification
gaps and availability of an authoritative Zig syntax package:

1. adapt maintained external tokenizers and parsers rather than duplicate them;
2. extract substantial owned parsers into independently versioned packages;
3. add small tolerant parsers for high-demand languages where lexical heuristics are inadequate;
4. retain bounded scanners for formats where parsing provides no meaningful highlighting benefit.

A backend changes from `lexical` to `parser_backed` only when it consumes real syntax structure. Merely
using the shared token storage is not enough.

## Third-Language Evaluation

Rust validates the shared model against a grammar that differs from both JavaScript and Bash. It
retains nested comments, attributes, raw and byte strings, lifetimes, and macro tokens while adding
flat structural nodes for the high-confidence roles required by highlighting. Parser tests cover
valid structure, partial malformed input, deterministic output, and all generic tree invariants.

The three owned parsers repeat a few small accessors, but their navigation policies are not actually
the same. Trivia differs by language, Bash command boundaries do not behave like brace-delimited
languages, and matching punctuation represented by a generic token tag requires source-aware rules.
The evaluation therefore does not add generic delimiter, trivia, declaration, or recovery helpers.
The core remains limited to storage, checked construction, tree validation, and a bounded cursor.

## Performance Evidence

The checked-in ReleaseFast comparison retains the former scanners as benchmark-only baselines:

```sh
./build.sh benchmark-syntax-core -- 500
```

A representative run on the committed focused corpora measured:

| Backend | Lexical baseline | Structural backend | Throughput ratio | Allocations, lexical / structural |
| --- | ---: | ---: | ---: | ---: |
| Bash | 412.03 MiB/s | 100.55 MiB/s | 0.244x | 5 / 16 |
| JavaScript | 108.39 MiB/s | 75.95 MiB/s | 0.701x | 4 / 13 |
| Rust | 95.55 MiB/s | 110.51 MiB/s | 1.157x | 5 / 15 |

These small-corpus observations are evidence, not permanent platform guarantees. Parsing has a
visible allocation cost, and its throughput impact depends more on the language implementation than
on the small storage core. Rust demonstrates that structural classification need not be slower;
Bash demonstrates that migration should not be automatic merely because the representation is
shared. Re-run the benchmark on target hardware and realistic consumer inputs before each future
migration.

## Current Decision

Keep the syntax core small and use it for owned tolerant highlighting parsers. Do not turn it into a
grammar framework or require lexical backends to adopt it. Migrate another language only when syntax
nodes materially improve classification, exact malformed-input behavior is tested, and measured
runtime and allocation costs are acceptable for that language.
