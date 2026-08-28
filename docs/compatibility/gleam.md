# Gleam Highlighting Compatibility

The verified structural Gleam backend is a parser-backed scanner. It recognizes
module imports and aliases, imported module references, type and constant
declarations, function declarations and qualified calls, parameters, `let`
patterns, `use` bindings, type annotations, constructors, record fields and
updates, bit-array modifiers, and external attributes in addition to the
shared lexical scopes.

The scanner is bounded and recovers from incomplete strings and declarations.
It does not perform semantic name resolution, validate patterns or types,
expand target attributes, or attempt to compile the source. Imported module
tracking is source-local and bounded; it does not inspect dependencies.
