# Applicative Lexer Evaluation

## Decision

Keep the direct procedural Bash tokenizer as the production implementation. Do
not switch Bash highlighting to the composable matcher in its evaluated form.

The experiment established correctness, clarified the boundary between regular
matching and shell state, and produced a repeatable performance comparison.
This is a performance and lifecycle decision, not a rejection of composable
lexical rules.

## Date And Status

- Date: 2026-08-22
- Status: evaluated; production adoption declined
- Preserved experiment: branch `feature/applicative-lexer`, commits `84521a8`
  through `42cb12f`

## Question

Could a Zig implementation of Roman Cheplyaka's applicative regular-expression
approach make language lexers more declarative while preserving the speed,
losslessness, and recovery behavior required by this syntax-highlighting
library?

The relevant ideas are:

- build larger regular languages from sequence, alternative, and repetition;
- attach captures and token results to those rules;
- run all eligible rules against the same prefix;
- choose the longest match, using rule order only to break equal-length ties;
- keep context-sensitive state in a language-specific driver.

References:

- <https://ro-che.info/docs/2012-04-20-applicative-regexps.pdf>
- <https://ro-che.info/articles/2015-01-02-lexical-analysis>

## Prototype

The experiment added three layers:

```text
composable regular rules
           |
           v
 NFA matcher / capture-free DFA
           |
           v
 contextual Bash tokenizer driver
           |
           v
 existing tolerant structural parser
```

The shared matcher supports symbols, byte predicates, sequences, alternatives,
consuming repetition, source-range captures, longest-prefix selection, and
stable priority. Capture-free rule groups can be determinized. A failed match
does not own recovery: the language driver must still consume an invalid byte or
terminate, preserving the parser's progress guarantee.

The Bash pilot divides regular rules into word, operator, and punctuation
machines and dispatches by the leading byte. It deliberately leaves these
features procedural:

- quote modes and escapes;
- command and arithmetic substitutions;
- context-sensitive comments;
- dynamic heredoc delimiters and bodies;
- recursive or input-dependent constructs.

This boundary is essential. Applicative regular expressions organize the
regular portion of a lexer; they do not make the Bash language regular.

## What The Experiment Proved

The declarative rules correctly expressed competing Bash token forms. In
particular, maximal munch keeps `127.0.0.1` and `123abc` whole while still
recognizing a standalone `8080` as a number. Stable priority distinguishes a
keyword such as `if` from a longer word such as `ifconfig`, and assignment
matches can expose structured name and operator ranges.

The contextual prototype reached exact parity with the direct parser for:

- tokens, syntax nodes, and diagnostics on a focused Bash corpus;
- tokens, syntax nodes, and diagnostics on a 1,209-line real-world installer;
- 500 deterministic malformed inputs;
- more than 1,000 regular-token comparisons on the installer corpus.

These tests show that the approach can coexist with tolerant, lossless Bash
parsing. They do not show that it is the right production implementation.

## Performance Evidence

The experiment includes a ReleaseFast benchmark comparing the direct parser,
the contextual prototype with precompiled rules, the same prototype with rules
compiled per parse, and the isolated regular matcher.

Representative measurements from the evaluation were:

| Input and mode | Direct parser | Contextual prototype | Contextual, rules compiled per parse |
| --- | ---: | ---: | ---: |
| 30,285-byte installer | 127.06 MiB/s | 84.44 MiB/s | 65.37 MiB/s |
| 302-byte focused corpus | 143.60 MiB/s | 93.32 MiB/s | 2.74 MiB/s |

The first unspecialized NFA pilot measured about 4.25 MiB/s. Splitting rule
groups, dispatching by leading byte, and determinizing capture-free rules raised
the regular-only pilot to approximately 63.73 MiB/s. That large improvement
validated the optimization direction, but the complete precompiled contextual
path still remained roughly one third slower than the direct parser.

The current public highlighting operation is stateless. It has no natural owner
for a runtime-compiled grammar, so the cold cost cannot simply be hidden in the
existing API. Small snippets make that lifecycle mismatch particularly visible.

The numbers above are representative observations, not permanent platform
guarantees. Re-run the benchmark from the experiment branch on the target
hardware before using them for a later decision.

## Consequences

- Production Bash highlighting continues to use the direct tokenizer.
- No rollback is necessary because the experimental path never replaced it.
- The prototype remains available on its branch as a correctness oracle, design
  reference, and optimization benchmark.
- A generic matcher should not be adopted merely to make lexical rules look
  uniform across languages. Each language must justify the runtime and
  maintenance cost.
- Longest-match bugs can often be fixed generally in a direct scanner. The
  `127.0.0.1` case motivated the experiment, but does not alone require a new
  lexer architecture.
- Resumable matching is not edit-based incremental parsing. Incremental editor
  support would additionally require state checkpoints, invalidation,
  convergence, token splicing, and structural reconciliation.

## Knowledge Preserved On The Experiment Branch

The branch retains independently committed slices for:

- the implementation plan and composable lexer contract;
- the NFA matcher and capture-free DFA determinization;
- regular Bash lexical rules and the contextual driver;
- real-world, parity, and malformed-input tests;
- the benchmark and both the initial and optimized measurements.

The key artifacts there are `docs/architecture/lexer-contract.md`,
`docs/plans/applicative-lexer-plan.md`, `src/lexer.zig`,
`src/parsers/bash_lexical_rules.zig`, `tests/bash_conformance.zig`,
`tests/corpus/bash/codex-install.sh`, and `tools/bash_lexer_benchmark.zig`.

This decision record belongs on `main` even though those executable research
artifacts remain isolated. It preserves the outcome if the feature branch is
eventually archived or deleted.

## Revisit When

Reconsider production adoption only when at least one of these conditions
changes:

- generated or compile-time static DFA tables eliminate runtime grammar setup;
- a reusable parser/highlighter context gives compiled rules an explicit owner;
- editor or LSP work creates a measured need for resumable lexical state;
- a second language demonstrates enough reuse to offset the generic machinery;
- a new implementation closes the complete-parser throughput gap without
  weakening ranges, diagnostics, losslessness, or malformed-input recovery.

A future attempt must compare complete parser output, not only isolated token
matching. The acceptance gate is exact behavioral parity plus no material
performance or allocation regression on both small snippets and realistic
corpora.
