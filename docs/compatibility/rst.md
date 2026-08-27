# reStructuredText Highlighting Compatibility

The dependency-free `rst` backend recognizes underline-style headings,
directives, directive options, comment lines, ordered and unordered lists,
interpreted roles and links, and inline literal spans. It is verified as a
source-preserving lexical scanner on representative documentation.

The scanner does not resolve references, validate directive bodies, infer
overline heading structure, parse tables, or execute embedded code. Incomplete
inline constructs remain bounded by their source line so later blocks recover.
