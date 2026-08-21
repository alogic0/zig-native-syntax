# Diff Highlighting Compatibility

The dependency-free `diff` backend is available as
`native_syntax.languages.diff`. It is a line-oriented scanner for unified and
Git-style patches, not a patch parser or applicability validator.

The scanner recognizes Git metadata keywords, old/new file headers, file-name
labels, hunk headers, added/deleted line markers, and the standard missing-final
newline annotation. Context and changed payload bytes remain plain text so the
backend does not assign programming-language semantics to embedded source.

Combined diffs, quoted Git paths, binary patch bodies, Subversion metadata,
mail headers, conflict markers, and semantic relationships between hunks are
not parsed. Incomplete headers are classified only where their line prefix is
recognizable, and all remaining bytes are preserved verbatim by the renderer.
