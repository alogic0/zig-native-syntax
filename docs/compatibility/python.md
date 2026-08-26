# Python Highlighting Compatibility

The dependency-free `python` backend is a tolerant, single-pass structural
parser. It recognizes comments, decorators, legal string prefixes, single and
triple quoted strings, escapes, keywords, function and class declarations,
parameters, annotations, imports, constructor and call sites, member access,
builtins, primitive values, numbers, operators, punctuation, and ASCII
identifiers. It is verified for structural highlighting on complete and
malformed application-shaped inputs.

The parser does not build an executable Python AST. It does not resolve names,
fully interpret indentation, parse comprehensions or pattern-matching
structure, accept Unicode identifiers, resolve soft-keyword context, or parse
expressions inside f-strings. Raw strings suppress escape captures; other
prefixed strings remain one source-preserving string region. Unterminated
single-line strings stop at a newline, while triple strings extend through end
of input.
