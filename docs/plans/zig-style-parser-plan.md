# Zig-Style Parser Architecture Plan

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

1. Document this architecture and migration policy.
2. Add the shared syntax core with focused ownership, cursor, and recovery tests.
3. Add the JavaScript/TypeScript tokenizer and structural parser with parser-level tests.
4. Replace the two direct scanners with adapters over tokens and syntax nodes; update metadata and
   conformance expectations.
5. Record compatibility boundaries and run the complete repository test gate.

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
