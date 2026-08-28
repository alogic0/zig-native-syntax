# D Highlighting Compatibility

The verified structural D backend combines the shared lexical scanner with the
shared tolerant C-like declaration parser. It recognizes qualified module and
import namespaces, aggregate type declarations, direct aggregate fields,
functions and parameters, local variables, known-type constructor calls, and
member access in addition to strings, comments, escapes, numbers, booleans,
keywords, primitive types, operators, and punctuation.

The parser is bounded and source-preserving around incomplete declarations. It
does not resolve imports or overloads, expand templates or mixins, evaluate
compile-time constructs, or validate types. Nested `/+ +/` comments retain the
lexical scanner's existing first-close recovery policy.
