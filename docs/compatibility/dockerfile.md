# Dockerfile Highlighting Compatibility

The dependency-free `dockerfile` backend is a composed highlighter. It
recognizes parser directives, standard instructions case-insensitively,
instruction flags, continuations, variables, and common argument tokens.
Shell-form `RUN` and `HEALTHCHECK CMD` regions delegate to the verified Bash
parser, while JSON instruction forms delegate to the verified JSON scanner.
Standard `RUN` heredoc bodies remain part of their Bash region.

The backend does not validate BuildKit mount grammar, variable expansion
semantics, build stages, or instruction-specific argument rules. It recognizes
one standard heredoc delimiter per `RUN` instruction; unusual compound heredoc
forms remain source-preserving but may not receive complete nested roles.
Comments are recognized as Dockerfile comments only when they begin a logical
instruction line.
