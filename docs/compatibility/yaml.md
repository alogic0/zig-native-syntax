# YAML Highlighting Compatibility

The dependency-free `yaml` backend is a line- and indentation-bounded lexical
scanner. It recognizes directives and document markers, mapping keys, sequence
markers, anchors, aliases, tags, comments, quoted strings and escapes, block
scalar markers and indented bodies, primitive values, and flow punctuation.

The backend is verified for lexical highlighting. Mapping-key context takes
precedence over primitive spelling, including numeric and boolean-shaped keys,
and block scalar bodies remain strings until indentation returns to the parent.

The scanner is not a YAML parser or schema resolver. It does not implement
indentation-based collections, complex keys, merge semantics, tag resolution,
directive semantics, multiline quoted-scalar folding, flow grammar, or YAML 1.1 versus
1.2 implicit typing. Block scalar bodies continue only while indentation is
deeper than their marker line. Unterminated quoted scalars stop at the current
line so subsequent mappings recover.
