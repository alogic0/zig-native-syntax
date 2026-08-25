# TypeScript Highlighting Compatibility

The dependency-free `typescript` backend uses the JavaScript syntax package in TypeScript mode. In
addition to the shared JavaScript tokens and nodes, it recognizes primitive type tokens, interfaces,
type aliases, enums, declaration modifiers, and selected type references following annotations,
`as`, `extends`, `implements`, and `satisfies`.

Interface, type-alias, enum, and class names are classified from declaration nodes rather than from a
"next identifier" scanner state. User-defined annotation references receive `type`; builtin
references can compose `builtin` and `type`. The parser recovers partial structure from incomplete
generic and function syntax without exposing diagnostics as highlighting failures.

The parser does not implement complete generic nesting, conditional or mapped types, overload sets,
decorators, declaration merging, namespaces, JSX/TSX, type checking, or symbol resolution. Complex
type expressions can therefore leave identifiers with their lexical classification. All JavaScript
regular-expression, template-expression, and Unicode-identifier limitations also apply.
Unsupported valid Unicode scalars therefore remain unclassified, while malformed or truncated
UTF-8 bytes remain invalid.
