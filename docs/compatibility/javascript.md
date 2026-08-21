# JavaScript Highlighting Compatibility

The dependency-free `javascript` backend is a byte-oriented lexical scanner.
It recognizes comments and documentation overlap, quoted and template strings,
escapes and template interpolation markers, keywords, declaration names,
private and dotted properties, common builtins, primitive values, numbers,
operators, punctuation, and ASCII identifiers.

The scanner does not parse automatic semicolon insertion, regex literals,
template interpolation expressions, JSX, Unicode identifiers, contextual
grammar, modules, scopes, or declaration references. Slash tokens remain
operators because reliable regex/division disambiguation requires parser
context. Unterminated quoted strings stop at a newline; block comments and
template strings extend through end of input.
