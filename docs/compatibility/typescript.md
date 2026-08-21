# TypeScript Highlighting Compatibility

The dependency-free `typescript` backend reuses the JavaScript scanner and
adds TypeScript declaration keywords and primitive type scopes. It recognizes
interfaces, type aliases, enums, access and declaration modifiers, common type
operators, and the shared JavaScript lexical constructs.

The scanner does not parse generic nesting, type expressions, overloads,
decorators, declaration merging, namespaces, JSX/TSX, or contextual identifier
roles. User-defined type references remain generic identifiers except for the
name immediately following a type-declaration keyword. All JavaScript regex,
template-expression, and Unicode-identifier limitations also apply.
