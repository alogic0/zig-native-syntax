# Elm Highlighting Compatibility

The verified structural Elm backend combines the shared lexical scanner with
the shared Elm/PureScript structural scanner. It recognizes modules and
imports, type aliases and custom types, constructors, function signatures and
equations, parameters, record fields, qualified modules, and member access.

The scanner is bounded and source-preserving around incomplete declarations.
It does not resolve imports, infer types, validate exposing lists, follow Elm's
layout rules completely, or compile the source.
