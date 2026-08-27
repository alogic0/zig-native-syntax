# C++ highlighting

The C++ backend combines the bounded lexical scanner with a tolerant C-like
declaration parser. It distinguishes namespaces, declared types, constructors,
functions, parameters, variables, member properties, and labels, including
qualified names separated by `::`.

The parser recovers at statement and block boundaries and remains
source-preserving for incomplete templates, declarations, strings, comments,
valid UTF-8, and arbitrary malformed bytes. It does not instantiate templates,
expand macros, resolve overloads, or validate a translation unit.
