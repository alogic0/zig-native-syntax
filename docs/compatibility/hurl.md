# Hurl Highlighting Compatibility

The dependency-free `hurl` backend recognizes HTTP request methods and URLs,
response protocol lines and status codes, headers, Hurl sections, assertion and
capture predicates, templates, comments, and quoted strings with escapes. It
is verified as a source-preserving lexical scanner on request/response files.

The scanner does not execute requests, validate HTTP or Hurl grammar, parse
JSON/XML bodies, resolve templates, or interpret predicate expressions.
Incomplete strings and templates remain bounded by their source lines.
