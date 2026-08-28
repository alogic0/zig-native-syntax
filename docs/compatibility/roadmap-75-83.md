# Roadmap Languages 75–83 Compatibility

D and V have separate verified structural contracts in `d.md` and `v.md`.

Odin, C3, SystemVerilog, LLVM IR, OpenSCAD, Nickel, and Hare use
dependency-free bounded lexical scanners. Each backend recognizes configured
comments, quoted strings and escapes, numbers, booleans and constants,
identifiers, calls, operators, punctuation, and a documented subset of
language keywords and primitive types.

These backends classify representative source and recover around malformed or
incomplete snippets, but they do not validate declarations, resolve names or
types, expand macros, evaluate compile-time constructs, or select language
versions. SystemVerilog preprocessing and compiler directives remain lexical; and LLVM
IR sigils are classified as adjacent punctuation/attribute and identifier
ranges rather than as a full SSA or global-name grammar.

OpenSCAD expressions are not evaluated, Nickel contracts and interpolation
are not interpreted, and embedded assembly or foreign source remains plain
text. Unterminated configured block comments extend to end of input. Quoted
strings stop at a newline so later lines can recover, and unclassified bytes
remain source-preserving escaped text.
