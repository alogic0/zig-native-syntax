# Bash Highlighting Compatibility

The dependency-free `bash` backend is available as `native_syntax.languages.bash`. Its canonical
name is `bash`; consumers own aliases such as `sh` and `shell`.

The backend uses the shared Zig-style syntax core with a Bash-specific tokenizer and tolerant
structural parser:

```text
source -> Bash tokens -> recovering syntax nodes -> highlighting captures
```

The tokenizer preserves original byte ranges for:

- line comments and shebangs;
- single, double, ANSI-C, and locale-style quoted strings;
- backslash escapes in expandable strings and ordinary source;
- named, positional, special, and braced variables;
- command substitutions using `$()` and backticks;
- arithmetic substitutions using `$((...))`;
- reserved words, decimal digit runs, operators, and grouping punctuation;
- static heredoc delimiters, quoted delimiters, `<<-` tab stripping, bodies, and terminators.

The parser produces nodes for simple commands, command names, arguments and options, assignments,
redirections and their targets, `function name` and `name()` definitions, and `for`/`select` loop
variables. Command position recovers at newlines, control operators, control-flow reserved words,
grouping braces, and after leading assignments or redirections. Parser diagnostics remain internal;
malformed source still yields trusted tokens and partial syntax nodes.

The adapter maps command and function-definition names to `function`, known Bash builtins to the
overlapping `builtin` scope, assignment and loop-variable names to `property`, assignment operators
to `operator`, and dash-prefixed command arguments to `constant`. These roles align with the semantic
categories in Tree-sitter Bash's official highlighting query, while the implementation remains an
independent native Zig parser. The GNU Bash builtin index is the authority for the builtin list.

Nested captures are intentional: variables, escapes, and substitutions inside double-quoted strings
overlap the enclosing `string` capture. The shared HTML renderer normalizes these scopes without
changing source bytes.

This is a structural highlighting parser, not a shell expander, executor, or validator. It does not
resolve aliases or functions, recursively parse commands inside substitutions, fully validate
control-flow or `case` grammar, interpret parameter-expansion operators, implement runtime heredoc
delimiter expansion, or account for command wrappers such as `sudo`, `env`, and `command` when
classifying later words. Complex dynamic heredoc delimiters and grammar outside the documented
subset can remain plain or receive conservative lexical scopes. Unterminated quotes, substitutions,
and heredocs extend to end of input and remain safely escaped rather than failing highlighting.

References:

- <https://github.com/tree-sitter/tree-sitter-bash/blob/master/queries/highlights.scm>
- <https://www.gnu.org/software/bash/manual/html_node/Builtin-Index.html>
