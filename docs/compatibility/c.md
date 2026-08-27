# C highlighting

The C backend combines a source-preserving lexical scanner with an owned,
tolerant declaration pass. The declaration pass distinguishes tag and typedef
types, functions, parameters, variables, member properties, and labels while
recovering at statement and block boundaries.

Preprocessor continuations, comments, literals, escapes, operators, malformed
declarations, arbitrary invalid bytes, and valid UTF-8 boundaries are covered
by the conformance suite. The parser is intended for highlighting and does not
claim to validate translation units or expand macros.
