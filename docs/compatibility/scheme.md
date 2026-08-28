# Scheme Highlighting Compatibility

The verified structural Scheme backend combines the shared lexical scanner
with the shared Lisp-family S-expression scanner. It recognizes libraries and
imports, variable and procedure definitions, parameters, record types and
fields, syntax definitions, lambda parameters, `let` bindings, calls,
booleans, and quoted data.

The scanner is bounded and source-preserving around incomplete forms and nested
block comments. It does not expand syntax, resolve libraries, implement every
Scheme reader extension, infer types, or evaluate source.
