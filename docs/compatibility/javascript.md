# JavaScript Highlighting Compatibility

The dependency-free `javascript` backend uses the repository's tolerant JavaScript syntax parser.
The tokenizer records original byte ranges for comments, quoted and template strings, keywords,
private identifiers, common builtins and primitive values, numbers, operators, punctuation, and
ASCII identifiers. The parser builds compact nodes for variable and function declarations,
bindings, parameters, calls, and member access.

The highlighting adapter maps lexical tokens and syntax nodes separately. Declaration bindings and
parameters no longer depend on next-character guesses. A member call such as `service.run()` applies
both `property` and `function` to `run`, using the classification model's overlapping-scope behavior.
Parser diagnostics remain internal; incomplete functions, strings, templates, and comments retain
the safe tokens and syntax nodes recognized before recovery.

This is a structural highlighting parser, not an ECMAScript validator. It does not validate
automatic semicolon insertion, parse regular-expression literals, recursively parse template
interpolation expressions, parse JSX, recognize Unicode identifiers, resolve bindings or modules,
or distinguish every method and property declaration form. Slash tokens remain operators because
reliable regex/division disambiguation requires fuller expression context. Unterminated quoted
strings stop at a newline; block comments and template strings extend through end of input.
