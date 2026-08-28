# Hare highlighting

The verified structural `hare` backend combines the bounded lexical scanner
with the shared tolerant declaration parser. It classifies `use` namespaces,
types, struct fields, functions, parameters, variables, `def` constants,
known-type struct constructors and initializer properties, qualified calls,
primitive types, comments, strings, escapes, values, operators, and
punctuation.

The parser accepts incomplete editor input and preserves unknown constructs. It
does not resolve imports, validate types or expressions, evaluate constants,
model match exhaustiveness, or distinguish every form of anonymous aggregate.
