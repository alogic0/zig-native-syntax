# Ziggy Schema Highlighting Compatibility

The optional `native_syntax_ziggy_schema` module is enabled independently with
`-Dbackend-ziggy-schema=true`. It uses the tokenizer from the pinned Ziggy package for resilient
lexical captures and its recovering schema AST for declaration and field context.

The adapter classifies struct and union keywords, root and type sigils, builtin and named types,
type declarations, field names, documentation comments, operators, punctuation, and invalid bytes.
Tokenizer captures remain available when the AST reports malformed or incomplete schema syntax, so
the shared HTML renderer can still produce escaped, readable output.

Like the document adapter, the schema adapter temporarily creates sentinel-terminated source for
Ziggy while all reported ranges continue to refer to the caller's original bytes.
Unsupported valid Unicode scalars emitted byte-by-byte as invalid by the external tokenizer remain
unclassified so captures stay on UTF-8 boundaries. Invalid UTF-8 input retains byte captures.
