# Haskell Compatibility

The verified structural Haskell backend recognizes module and import names,
algebraic type and class declarations, constructors, record fields, function
signatures and equations, equation parameters, type references, and language
pragmas. Its lexical foundation classifies line and block comments, strings,
escapes, numbers, booleans, operators, and punctuation.

The parser is deliberately tolerant and bounded. It does not apply layout
rules, resolve names, parse every symbolic declaration, infer types, or expand
Template Haskell. Nested comments are skipped structurally; unterminated
comments, strings, signatures, and equations retain their original bytes and
do not require a valid module.
