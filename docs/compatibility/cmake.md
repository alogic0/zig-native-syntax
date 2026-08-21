# CMake Highlighting Compatibility

The dependency-free `cmake` backend recognizes comments, command calls,
control-flow keywords, variables, strings and escapes, booleans, constants,
numbers, operators, and punctuation. It is a bounded lexical scanner, not a
CMake evaluator; it does not expand variables, interpret generator
expressions, or validate command signatures. Unterminated strings stop at the
current line.
