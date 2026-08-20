# Zig Highlighting Compatibility

The Zig backend targets semantic usefulness and source preservation rather than HTML or capture-name
compatibility with another renderer. This review records the Phase 3 baseline so later changes can
distinguish corrections from deliberate policy changes.

## Review Basis

The representative inputs are the complete, malformed, incomplete, and golden fixtures in
`tests/corpus/zig/`. The comparison used:

- the tokenizer, recovering AST, and documentation HTML renderer shipped with the pinned Zig
  compiler;
- the Zig highlighting query used by Zine's current flow-syntax and Tree-sitter path;
- the deterministic HTML asserted by `tests/zig_corpus.zig`.

The golden test fixes this package's structural output. CSS colors and typography remain consumer
owned and will be compared in Zine during Phase 9.

## Classification Comparison

| Construct | Native backend | Zig documentation renderer | Zine Tree-sitter path |
| --- | --- | --- | --- |
| Keywords | `keyword` | keyword token class | specialized keyword captures |
| Strings and characters | `string`, with overlapping `escape` where applicable | string token class | string/character plus escape captures |
| Builtins | `builtin` | builtin token class | builtin function capture |
| Primitive types | overlapping `builtin` and `type` | type token class | builtin type capture |
| Primitive values | `boolean` or `constant` | shared primitive-value class | boolean or builtin constant |
| Other identifiers | baseline `variable` | usually unstyled or linked | baseline variable plus query refinements |
| Function declarations | overlapping `variable` and `function` | function class, sometimes linked | function capture |
| Direct and member calls | overlapping `variable` or `property` and `function` | usually unstyled or linked through documentation context | function-call capture |
| Parameters | overlapping `variable` and `parameter` | usually unstyled | parameter capture |
| Container fields and field access | overlapping `variable` and `property` | unstyled or linked through documentation context | member capture |
| Operators and punctuation | explicit `operator` and `punctuation` | escaped text without a token class | operator and punctuation captures |
| Documentation comments | overlapping `comment` and `documentation` | comment token class | documentation/comment captures |
| Ordinary comments | recovered as `comment` from tokenizer gaps | recovered as comment text | comment capture |
| Invalid tokens | `invalid`, with later tokens retained when tokenization permits | rendering can fail on an invalid token | parser recovery-dependent error regions |

## Intentional Differences

- The native backend emits stable `syntax-*` classes, not Zig documentation `tok-*` classes or
  Tree-sitter capture names.
- Contextual classifications overlap lexical classifications. For example, a function name remains
  an identifier while also receiving `function`; the shared renderer emits both classes in stable
  order.
- Type names are inferred only from syntax-backed declarations and Zig primitive knowledge. The
  backend does not classify every capitalized identifier as a type.
- The backend does not resolve declarations, produce documentation links, or annotate source
  locations.
- Operators and punctuation receive explicit classes even though Zig's documentation renderer emits
  many of them as plain escaped text.
- Input indentation and whitespace are preserved exactly. The documentation renderer can unindent or
  collapse whitespace for its presentation context.
- The shared HTML renderer escapes both quote characters in addition to ampersands and angle
  brackets. This is stricter than required for some text-only contexts but keeps one safe policy.
- Malformed syntax is not a highlighting error. Lexical classifications are retained and AST context
  is added only where the recovering parser produced reliable nodes.

## Phase 3 Result

The corpus covers declarations, expressions, documentation and ordinary comments, multiline
strings, builtins, malformed tokens, and incomplete syntax. Debug and ReleaseSafe tests verify that
all fixtures classify and render without a C or Tree-sitter dependency. The Zine integration remains
responsible for mapping these classes into its theme and reviewing the resulting appearance.
