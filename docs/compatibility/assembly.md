# Assembly highlighting

The verified `asm` and `nasm` backends share an architecture-neutral dedicated
scanner. It recognizes common GNU and NASM directives, macro declarations,
instruction names, registers, size names, label declarations and branch
targets, comments, literals, numbers, operators, and punctuation. The
`assembly` and `gas` labels route to `asm`.

The scanner preserves dialect differences such as GNU `#` comments and
dot-directives versus NASM `;` comments and percent-prefixed macro directives.
It deliberately does not select or validate an instruction set, operand width,
directive arguments, macro expansion, or ABI conventions. Unknown words remain
unclassified instead of being presented as validated assembly symbols.
