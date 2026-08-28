# Odin Highlighting Compatibility

The verified structural Odin backend combines the shared lexical scanner with
the shared tolerant C-like declaration parser. It recognizes packages,
double-colon type, procedure, and constant declarations, aggregate fields,
procedure parameters, short variable declarations, known-type compound
literals, calls, and member access.

The parser is bounded and source-preserving around incomplete declarations. It
does not resolve imports, infer types, evaluate compile-time declarations,
expand polymorphic procedures, or compile the source.
