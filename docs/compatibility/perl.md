# Perl Compatibility

The verified structural Perl backend recognizes packages and imported modules,
subroutine declarations and signature parameters, sigiled variables,
dereference properties, hash keys, labels, builtin calls, quote-like and regex
operators, substitutions, ordered same-statement heredocs, and POD
documentation. Its lexical foundation classifies comments, ordinary strings,
escapes, numbers, booleans, constants, operators, and punctuation.

The parser is deliberately tolerant and bounded. It does not execute compile-
time blocks, resolve barewords, infer prototypes, interpolate regexes or
heredocs, or disambiguate every slash operator permitted by Perl's grammar.
Unterminated strings, regexes, substitutions, heredocs, POD blocks, and
signatures retain their source bytes and recover without compiling the input.
