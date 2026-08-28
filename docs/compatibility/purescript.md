# PureScript Highlighting Compatibility

The verified structural PureScript backend combines the shared lexical scanner
with the shared Haskell/Elm/PureScript structural scanner. It recognizes modules and
imports, data, newtype, type-synonym, and class names, constructors, function
signatures and equations, parameters, record fields, qualified modules, and
member access.

The scanner is bounded and source-preserving around incomplete declarations.
It does not resolve imports, infer kinds or types, validate instances, follow
layout rules completely, or compile the source.
