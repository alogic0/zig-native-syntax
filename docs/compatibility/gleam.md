# Gleam Highlighting Compatibility

The Gleam backend is an experimental parser-backed scanner. It recognizes
module imports, type and constant declarations, function declarations and
calls, parameters and type annotations, constructors, record fields, and
external attributes in addition to the shared lexical scopes.

The scanner is bounded and recovers from incomplete strings and declarations.
It does not resolve imported names, validate patterns or types, expand target
attributes, or attempt to compile the source. Experimental status is retained
while the structural corpus grows and behavior is compared with the Gleam
compiler and formatter.
