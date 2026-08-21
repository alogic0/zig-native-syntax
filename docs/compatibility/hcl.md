# HCL Highlighting Compatibility

The dependency-free `hcl` backend is a bounded lexical scanner. It recognizes
line and block comments, quoted strings and escapes, template introducers,
heredoc markers and bodies, common block and expression keywords, primitive
types and values, object properties, traversal attributes, function calls,
numbers, operators, and collection punctuation.

The scanner is not an HCL parser or evaluator. It does not validate block
schemas, expression precedence, traversal validity, heredoc indentation, or
template directives and interpolation bodies. Template introducers in quoted
strings receive an embedded scope, while heredoc bodies remain strings through
the matching delimiter. Unterminated quoted strings stop at the current line;
unterminated block comments and heredocs extend to end of input.
