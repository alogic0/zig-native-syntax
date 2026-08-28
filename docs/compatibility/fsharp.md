# F# Compatibility

The verified structural F# backend uses the shared tolerant ML-family parser.
Its lexical scanner traverses the source once, then structural state refines
the emitted captures without rescanning source bytes. It recognizes namespaces and opened modules, type and value declarations,
members, declaration parameters, optional parameters, discriminated-union
constructors and named fields, record fields, type annotations, attributes,
and line directives. Its lexical foundation classifies nested block and line
comments, ordinary and triple-quoted strings, escapes, literals, numbers,
operators, and punctuation.

The source-traversal design and reproducible performance comparison are
documented in [ML-family scanner performance](../architecture/ml-family-performance.md).

The parser does not type-check patterns, resolve modules or overloads, expand
computation expressions, or fully parse active patterns, quotations, units of
measure, interpolated strings, or statically resolved type parameters. Space-
applied calls remain conservatively classified. Unterminated comments,
strings, attributes, declarations, and type annotations retain their source
bytes and recover without a valid compilation unit.
