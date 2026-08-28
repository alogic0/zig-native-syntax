# Fortran highlighting

The verified structural Fortran backend provides case-insensitive highlighting
for free- and fixed-form source. Its single source pass recognizes fixed-form
comments, statement labels and column-six continuation markers as well as
free-form `&` continuations, doubled-quote string escapes, BOZ literals,
kind-suffixed numbers, dot-delimited logical values and operators, intrinsic
types, procedures, comments, operators, and punctuation. Tolerant line state
classifies programs and modules as namespaces; functions, subroutines,
calls, and procedure bindings as functions; dummy arguments as parameters;
derived types and parent types; and derived-type components as properties. It
preserves incomplete statements and does not attempt module resolution,
generic resolution, or implicit typing.
