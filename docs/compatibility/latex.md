# LaTeX Highlighting Compatibility

The dependency-free `latex` backend recognizes control words and symbols,
environment names after `begin` and `end`, inline and display math regions,
comments, argument punctuation, parameter and script operators, and numbers.
It is verified as a source-preserving lexical scanner on complete and malformed
documents.

The scanner does not expand macros, interpret catcodes, validate environments,
parse nested math delimiters, or distinguish text from package-defined syntax.
An unterminated math region extends through end of input; comments extend only
through their source line.
