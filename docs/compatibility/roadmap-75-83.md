# Roadmap Languages 75–83 Compatibility

D, V, Odin, C3, SystemVerilog, OpenSCAD, Hare, and Nickel have separate verified
structural contracts in `d.md`, `v.md`, `odin.md`, `c3.md`,
`systemverilog.md`, `openscad.md`, `hare.md`, and `nickel.md`.

LLVM IR uses a dependency-free bounded lexical scanner. It recognizes
comments, quoted strings and escapes, numbers, booleans and constants,
identifiers, calls, operators, punctuation, and a documented subset of
language keywords and primitive types.

This backend classifies representative source and recovers around malformed or
incomplete snippets, but it does not validate declarations, resolve names or
types, expand macros, evaluate compile-time constructs, or select language
versions. LLVM IR sigils are classified as adjacent punctuation/attribute and identifier
ranges rather than as a full SSA or global-name grammar.

Embedded assembly or foreign source remains plain
text. Unterminated configured block comments extend to end of input. Quoted
strings stop at a newline so later lines can recover, and unclassified bytes
remain source-preserving escaped text.
