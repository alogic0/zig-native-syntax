# Make Highlighting Compatibility

The dependency-free `make` backend is a line-bounded lexical scanner. It
recognizes directives, assignment keys and operators, target labels, variable
references, quoted strings and escapes, comments, and tab-prefixed recipe
lines. Recipe bodies are composed with the verified Bash parser, while Make
variable references retain their outer-language role.

The backend is verified for structural highlighting of the Make/shell boundary
and for lexical Make roles across application and library build corpora.

The scanner is not a Make evaluator. It does not expand variables, distinguish
GNU Make dialect extensions, resolve continuations, or parse Make functions and
nested references. Unterminated strings stop at the current line so later
assignments and targets recover.
