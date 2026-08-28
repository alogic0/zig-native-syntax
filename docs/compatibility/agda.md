# Agda highlighting

The verified structural `agda` backend combines lexical recovery with a
layout-aware tolerant declaration scanner. It classifies modules and imports,
data and record types, lower-case constructors, record fields, signatures,
equations, equation parameters, built-in universes, literals, and comments.

The backend does not type-check dependent expressions, resolve mixfix names,
expand modules, or validate layout and termination.
