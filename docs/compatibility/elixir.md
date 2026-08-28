# Elixir Compatibility

The verified structural Elixir backend recognizes module and protocol names,
function and macro declarations, parenthesized and anonymous-function
parameters, module aliases, calls, keyword keys, atoms, module attributes, and
sigils. Its lexical foundation also classifies comments, quoted and heredoc
strings, escapes, numbers, booleans, constants, operators, and punctuation.

The parser is deliberately tolerant and bounded. It does not expand macros,
resolve aliases, validate guards or typespecs, interpret sigil contents, or
distinguish every no-parentheses call from an ordinary variable. Unterminated
strings, sigils, declarations, and delimiter lists retain source bytes and
recover without requiring a valid compilation unit.
