# Julia Compatibility

The verified structural Julia backend recognizes modules, abstract and concrete
type declarations, long and short function forms, declaration parameters,
type annotations and bounds, macro declarations and invocations, qualified
names, symbols, and common Latin, Greek, and Cyrillic Unicode identifiers. Its
lexical foundation classifies nested-comment regions, strings, escapes,
numbers, booleans, constants, operators, and punctuation.

The parser is tolerant and bounded rather than a Julia evaluator. It does not
expand macros, resolve multiple dispatch, validate `where` clauses, interpret
string interpolation, or fully classify Julia's complete Unicode identifier
and operator-name policy. Unsupported valid Unicode remains unclassified; malformed constructs
retain their original bytes and recover without a valid compilation unit.
