# Tree-sitter Query Highlighting Compatibility

The dependency-free `query` backend is a tolerant S-expression event parser.
It recognizes node names, field labels, captures, predicates, anonymous nodes,
strings and escapes, quantifiers, anchors, constants, delimiters, and comments.
It is verified for structural highlighting on complete and malformed queries.

The parser does not load a target grammar, validate node or field names,
evaluate predicates, resolve captures, or enforce balanced delimiters. It
continues classifying later expressions after incomplete groups and strings.
