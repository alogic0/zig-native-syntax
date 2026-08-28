# OCaml Compatibility

The verified structural OCaml backend uses the shared tolerant ML-family
parser. Its lexical scanner traverses the source once, then structural state
refines the emitted captures without rescanning source bytes. It recognizes modules and qualified opens, type and value declarations,
declaration parameters, labelled parameters, type variables, variant
constructors, record fields, type annotations, and attributes. Its lexical
foundation classifies nested comments, strings and escapes, literals, numbers,
operators, and punctuation.

The parser does not type-check patterns, resolve modules, expand extensions,
interpret PPX attributes, or fully distinguish space-applied functions from
ordinary values. Object syntax, first-class modules, locally abstract types,
and quoted-string extensions receive bounded lexical recovery rather than a
complete grammar. Unterminated comments, strings, attributes, and declarations
retain their source bytes.
