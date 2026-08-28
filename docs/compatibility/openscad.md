# OpenSCAD highlighting

The verified structural `openscad` backend combines the bounded lexical scanner
with the shared tolerant declaration parser. It classifies module and function
declarations, their parameters, local and comprehension bindings, calls, named
arguments, primitive types, `undef`, comments, strings, escapes, numbers,
booleans, operators, and punctuation.

The parser accepts incomplete editor input and preserves unknown constructs. It
does not evaluate geometry, expand `include` or `use`, resolve module overloads,
infer types, or validate expressions and modifier characters.
