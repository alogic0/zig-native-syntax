# Uxntal Compatibility

The Uxntal backend uses a dedicated, dependency-free lexical scanner. It
recognizes nested parenthesized comments, raw ASCII tokens, hexadecimal byte
and short literals, padding and number runes, parent and child labels, address
references, macro declarations, wrapping punctuation, and the complete opcode
set with combinations of the `2`, `k`, and `r` modes.

The scanner does not assemble source, track label scopes, expand macros, or
validate stack effects. Plain words are left unclassified because a name can
resolve differently after macro expansion and label lookup. Unterminated
comments extend safely to end of input, unsupported text stays unclassified,
and malformed bytes retain the shared arbitrary-byte recovery.
