# Rust Highlighting Compatibility

The dependency-free `rust` backend is available as
`native_syntax.languages.rust`. It uses a byte-oriented tokenizer and a
tolerant structural parser built on the shared syntax model:

```text
source -> Rust tokens -> recovering syntax nodes -> highlighting captures
```

The tokenizer recognizes:

- line comments, nested block comments, and documentation-comment overlap;
- outer and inner attributes as source-preserving attribute regions;
- cooked, byte, raw, raw-byte, character, and byte-character literals;
- escape sequences in cooked strings and character literals;
- lifetimes and loop labels separately from character literals;
- decimal, base-prefixed, underscored, floating-point, exponent, and suffixed
  numeric token shapes;
- stable and commonly encountered contextual keywords;
- booleans and primitive types;
- ASCII identifiers, macro invocations, operators, and punctuation.

The parser adds structural roles for:

- function declarations and calls;
- function parameters and `let` bindings;
- struct and union fields plus member access;
- struct, union, enum, trait, and type-alias names;
- type references in parameters, fields, return types, aliases, and `impl`
  headers;
- module names, constants, statics, and enum variants.

Raw strings support arbitrary hash counts. An incomplete raw or cooked string
is classified through end of input. Nested block comments are tracked by depth
and likewise extend through end of input when unterminated. These recovery
rules preserve malformed snippets without exposing syntax errors through the
backend API.

Attributes are classified as whole regions; their internal paths, literals,
and meta-item grammar are not recursively classified. Macro bodies are scanned
lexically without expansion. The parser is intentionally shallow: it does not
build expression trees, expand patterns, resolve names, distinguish every path
role, validate generic arguments, or implement edition-specific grammar.
Identifiers outside its documented structural positions remain generic
`variable` captures. Non-ASCII identifier bytes remain safely represented as
invalid or escaped source rather than being normalized.

This is a highlighting parser, not a compiler-quality Rust parser, macro
expander, name resolver, borrow checker, or validator. Full Rust conformance is
outside the backend's ownership boundary.
