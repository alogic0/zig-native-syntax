# Regular Expression Highlighting Compatibility

The dependency-free `regex` backend is a dialect-neutral lexical scanner. It
recognizes escapes inside and outside character classes, negated character
classes, anchors, wildcard atoms, capturing and non-capturing group prefixes,
named captures, inline flag prefixes, alternation, and greedy, lazy, possessive,
and bounded quantifiers. It is verified on complete and malformed patterns.

The scanner deliberately does not choose PCRE, ECMAScript, RE2, Oniguruma, or
another grammar. It does not validate nesting, backreferences, flag legality,
Unicode property names, or class ranges. An unterminated class or named group
extends only as far as the scanner can identify without discarding source.
