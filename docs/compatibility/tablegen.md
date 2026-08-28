# TableGen highlighting

The verified TableGen backend parses declaration heads for classes,
multiclasses, definitions, and inherited records. It also recognizes field
assignments, bang operators, variables, builtin types, strings, code blocks,
comments, values, operators, and punctuation.

The tolerant parser recovers from incomplete records and code blocks without
attempting record expansion, template evaluation, or backend-specific semantic
validation.
