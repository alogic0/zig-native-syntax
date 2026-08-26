# Ziggy Highlighting Compatibility

The external `native_syntax_ziggy` module adapts the tokenizer from the pinned Ziggy package. It is
enabled by default and can be excluded with `-Dbackend-ziggy=false`. A core-only build can select it
with `-Dexternal-backends=false -Dbackend-ziggy=true`.

The adapter classifies comments, strings and multiline byte lines, integer and floating-point
numbers, booleans, nulls, enum values, union constructors, field names, operators, and punctuation.
It retains byte locations into the original source and continues tokenizing after malformed input.
Parser validation and semantic schema validation remain Ziggy's responsibility rather than part of
syntax highlighting.

The tokenizer requires sentinel-terminated input, so the adapter temporarily copies borrowed source
using the capture sink's allocator. Captures still refer to ranges in the caller's original bytes.
Unsupported valid Unicode scalars emitted byte-by-byte as invalid by the external tokenizer remain
unclassified so captures stay on UTF-8 boundaries. Invalid UTF-8 input retains byte captures.
