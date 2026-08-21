# SQL Highlighting Compatibility

The dependency-free `sql` backend is a dialect-neutral lexical scanner. It
recognizes common keywords and data types case-insensitively, line and block
comments, single-quoted and dollar-quoted strings, doubled-quote escapes,
quoted identifiers, positional and named parameters, primitive values,
function-shaped identifiers, numbers, operators, and punctuation.

The scanner does not select or validate a database dialect. It does not parse
procedural languages, vendor operators, nested block comments, query structure,
identifier roles, statement termination, or dollar-quoted body contents.
Unterminated comments and quotes extend through end of input, preserving the
source without reporting a syntax error.
