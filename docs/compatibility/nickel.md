# Nickel highlighting

The verified structural `nickel` backend combines bounded lexical recovery with
a focused tolerant scanner for `let` bindings, named functions, `fun`
parameters, record fields and metadata, dotted record paths, field access, and
string interpolation. Types, values, comments, strings, escapes, operators, and
punctuation retain lexical coverage.

The backend does not evaluate contracts, imports, recursive records, merge
priorities, pattern matching, or whitespace function application.
