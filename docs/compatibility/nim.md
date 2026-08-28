# Nim Highlighting Compatibility

The verified structural Nim backend combines the shared lexical scanner with
the tolerant declaration parser and a bounded pragma pass. It recognizes
imports, type and object declarations, exported names, object fields,
procedures, functions, methods, iterators, templates, macros, parameters,
variables, constants, constructors, named arguments, member access, and
pragmas.

The parser is source-preserving around incomplete declarations and nested
comments. It does not apply indentation semantics completely, expand macros or
templates, resolve overloads or imports, infer types, or compile the source.
