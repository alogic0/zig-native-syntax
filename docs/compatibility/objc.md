# Objective-C highlighting

The verified structural Objective-C backend recognizes C-family lexical
constructs together with Objective-C directives, nominal declarations,
properties, method declarations, selector pieces, message sends, and method
parameters. It is tolerant rather than a compiler and does not expand macros
or resolve selector and type names. Multiline method declarations, nested
block signatures, lightweight generics and protocol-qualified types, boxed
collection/value literals, Objective-C strings, and `@selector(...)` receive
dedicated recovery and structural coverage.
