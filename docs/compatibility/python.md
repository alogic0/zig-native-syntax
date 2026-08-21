# Python Highlighting Compatibility

The dependency-free `python` backend is a byte-oriented lexical scanner. It
recognizes comments, decorators, common string prefixes, single and triple
quoted strings, escapes, keywords, declaration names after `def` and `class`,
builtins, primitive values, numbers, operators, punctuation, and ASCII
identifiers.

The scanner does not parse indentation, annotations, comprehensions, pattern
matching structure, Unicode identifiers, soft-keyword context, or expressions
inside f-strings. Raw strings suppress escape captures; other prefixed strings
remain one source-preserving string region. Unterminated single-line strings
stop at a newline, while triple strings extend through end of input.
