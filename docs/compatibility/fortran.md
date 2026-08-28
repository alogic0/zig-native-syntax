# Fortran highlighting

The verified Fortran backend provides case-insensitive lexical highlighting
for free- and fixed-form source. Its dedicated scanner recognizes fixed-form
comments, statement labels and column-six continuation markers as well as
free-form `&` continuations, doubled-quote string escapes, BOZ literals,
kind-suffixed numbers, dot-delimited logical values and operators, intrinsic
types, procedures, comments, operators, and punctuation. It preserves
incomplete statements and does not attempt module resolution or implicit
typing.
