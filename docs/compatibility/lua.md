# Lua Highlighting Compatibility

The dependency-free `lua` backend is a tolerant, single-pass structural
parser. It recognizes line and balanced long comments, short and balanced long
strings, Lua escape forms, numbers, keywords, primitive values, local and
function declarations, parameters, labels, calls, member access, builtins,
operators, punctuation, and ASCII identifiers. It is verified for structural
highlighting on complete and malformed application-shaped inputs.

The parser does not build or evaluate a Lua AST, resolve names, infer table
shapes, accept Unicode identifiers, or parse expressions into a precedence
tree. Long-bracket delimiters must have matching equals counts. Unterminated
long literals extend through end of input, and incomplete short strings stop at
a newline so following statements remain highlightable.
