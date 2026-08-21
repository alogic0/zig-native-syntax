# JSON Highlighting Compatibility

The dependency-free `json` backend is available as
`native_syntax.languages.json`. It is a byte-oriented, source-preserving
lexical scanner. Zig's `std.json.Scanner` is used as the valid-corpus grammar
oracle in tests, but it does not expose the source offsets required by the
highlighting capture API.

The scanner recognizes:

- object and array punctuation;
- quoted object member names as properties;
- quoted values as strings;
- simple and Unicode escape sequences inside properties and strings;
- JSON number token shapes, including fractions and exponents;
- `true` and `false` as booleans;
- `null` as a constant.

Incomplete strings extend through end of input. Incomplete number components
and literal prefixes are classified through the recognizable prefix. Unknown
bytes remain safely escaped plain text, allowing classification to resume at
the next recognized JSON token.

This backend is not a validator and does not classify comments, single-quoted
strings, unquoted member names, hexadecimal numbers, `NaN`, `Infinity`, or
other JSON5 extensions. It does not diagnose duplicate member names, invalid
Unicode scalar sequences, nesting errors, misplaced punctuation, or other
grammar violations. Use `std.json.Scanner` or an application parser when JSON
validity matters.
