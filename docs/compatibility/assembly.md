# Assembly highlighting

The verified `asm` backend provides architecture-neutral lexical highlighting
for common GNU-style instruction names, registers, labels, comments, literals,
numbers, operators, and punctuation. The `assembly` and `gas` labels route to
the same backend. It deliberately does not validate instruction sets, operand
widths, directives, or ABI conventions.
