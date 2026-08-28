# JSDoc Highlighting Compatibility

The dependency-free `jsdoc` backend treats the complete input as documentation
and comment text, then adds lexical roles for `@` tags, balanced single-line
type expressions, required and optional parameter names, backtick code spans,
and inline `{@link ...}` forms. It is verified on complete and malformed API
documentation.

The scanner does not validate tag-specific argument grammar, TypeScript type
syntax, Markdown, link targets, or comment-delimiter placement. Type expressions
and code spans stop at a newline when incomplete, preserving later lines.
