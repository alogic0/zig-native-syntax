# V Highlighting Compatibility

The verified structural V backend combines the shared lexical scanner with the
shared tolerant C-like declaration parser. It recognizes modules and imports,
struct and interface declarations, direct fields whose type follows the name,
functions and method receivers, parameters, short variable declarations,
known-type struct literals, named initializer fields, and member access.

The parser is bounded and source-preserving around incomplete declarations. It
does not resolve imports, infer types, validate generic constraints, expand
compile-time constructs, or compile the source.
