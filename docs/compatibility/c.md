# C Highlighting Compatibility

The dependency-free `c` backend is a byte-oriented lexical scanner. It
recognizes preprocessing lines including continuations, line and block
comments, documentation-comment overlap, prefixed string and character
literals, escapes, C keywords and common types, primitive values,
function-shaped identifiers, numbers, operators, punctuation, and ASCII
identifiers.

The backend intentionally does not depend on Aro: compiler-grade preprocessing,
parsing, target types, diagnostics, and semantic storage are unnecessary for
source-preserving highlighting. The scanner does not expand macros, evaluate
conditional compilation, resolve typedef names, parse declarators, classify
fields contextually, or validate literal suffixes and escapes. Unterminated
comments and literals remain bounded by end of input or the literal's line.
