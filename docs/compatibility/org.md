# Org Mode Highlighting Compatibility

The dependency-free `org` backend recognizes heading levels and TODO states,
directives, source-block languages and bodies, drawers and properties, ordered
and unordered list markers, links, and comment lines. It is verified as a
source-preserving lexical scanner on representative notes and project files.

The scanner does not evaluate Babel blocks, parse embedded languages, resolve
links, interpret timestamps, or validate drawer and block nesting. An
unterminated link is bounded by its line; an unterminated source block marks
the remaining lines as embedded source.
