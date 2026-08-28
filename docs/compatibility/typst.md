# Typst highlighting

The verified structural Typst backend composes markup scanning with embedded
Typst code and math highlighting. It recognizes headings, labels and
references, raw spans and fenced blocks, code markers, declarations, function
parameters, calls, named arguments, variables, strings, comments, and math
expressions. Content inside raw blocks remains literal; the backend does not
compile Typst or resolve packages and references.
