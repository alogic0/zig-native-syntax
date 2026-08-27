# MLIR highlighting

The verified MLIR scanner recognizes SSA values, symbols, block labels, type
aliases, attributes, dialect operations, builtin scalar and shaped types,
comments, strings, escapes, values, operators, and punctuation. MLIR's sigils
make these roles reliable without symbol resolution.

The scanner preserves incomplete generic forms and arbitrary operations. It
does not validate dialect-specific assembly formats or operation constraints.
