# Protocol Buffers Highlighting Compatibility

The dependency-free `proto` backend combines a source-preserving lexical pass
with a tolerant declaration parser. It recognizes comments, strings and
escapes, numbers, keywords, scalar types, package namespaces, message, enum,
service, oneof, and extension type declarations, fields, enum constants,
options, and RPC names. It is verified for structural highlighting on complete
and malformed schema-shaped input.

The parser does not resolve imports or type names, validate field numbers,
options, maps, reservations, or RPC signatures, or enforce a proto2/proto3
dialect. Incomplete comments, strings, braces, and declarations preserve their
source and allow later tokens to be classified where boundaries remain clear.
