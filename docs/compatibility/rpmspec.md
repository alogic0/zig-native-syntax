# RPM Spec Highlighting Compatibility

The dependency-free `rpmspec` backend recognizes preamble tags and numeric
values, macros, package sections, comments, file directives, and changelog
entries. Shell-bearing build and scriptlet sections are delegated to the
parser-backed RPM Bash backend, so shell keywords, variables, strings, escapes,
calls, and recovery retain their structural roles. The composed backend is
verified on complete and malformed package specifications.

The scanner does not expand macros, evaluate conditionals, validate package
metadata, select a scriptlet interpreter, or parse dependency expressions.
Only the conventional Bash-backed sections are composed; descriptions, file
lists, and changelogs retain focused spec-file roles.
