# Rust Highlighting Compatibility

The dependency-free `rust` backend is available as
`native_syntax.languages.rust`. It is a byte-oriented lexical scanner, not a
Rust parser, macro expander, name resolver, or validator.

The scanner recognizes:

- line comments, nested block comments, and documentation-comment overlap;
- outer and inner attributes as source-preserving attribute regions;
- cooked, byte, raw, raw-byte, character, and byte-character literals;
- escape sequences in cooked strings and character literals;
- lifetimes and loop labels separately from character literals;
- decimal, base-prefixed, underscored, floating-point, exponent, and suffixed
  numeric token shapes;
- stable and commonly encountered contextual keywords;
- booleans and primitive types;
- ASCII identifiers, macro invocations, operators, and punctuation.

Raw strings support arbitrary hash counts. An incomplete raw or cooked string
is classified through end of input. Nested block comments are tracked by depth
and likewise extend through end of input when unterminated. These recovery
rules preserve malformed snippets without exposing syntax errors through the
backend API.

Attributes are classified as whole regions; their internal paths, literals,
and meta-item grammar are not recursively classified. Macro bodies are scanned
lexically without expansion. Identifier roles such as function, type,
property, parameter, and binding require parser context and remain generic
`variable` captures except for primitive types and macro calls. Non-ASCII
identifier bytes remain safely escaped plain text. Edition-specific grammar
and semantic validity are outside this backend's compatibility claim.
