# Roadmap Languages 25–42 Compatibility

These dependency-free backends are bounded lexical scanners. They classify
source without validating programs, expanding macros, resolving names, or
evaluating embedded languages.

- `java`, `c-sharp`, `cpp`, `go`, `kotlin`, `swift`, and `objc` recognize their
  documented keyword and primitive-type sets, comments, attributes,
  identifiers, calls, numbers, strings and escapes, operators, and punctuation.
  C++ and Objective-C also classify line-leading preprocessor directives.
- `powershell`, `php`, `lua`, and `ruby` recognize language keywords, comments,
  variables where prefixed, calls, values, and quoted literals. PowerShell
  here-strings, PHP heredocs, Lua long strings beyond `--[[` comments, and Ruby
  percent literals and heredocs remain plain or receive only lexical scopes.
- `asm` and `nasm` recognize common mnemonics, registers and size names,
  labels, comments, numbers, strings, operators, and punctuation. They do not
  select an instruction set or validate operands and directives.
- `vue` and `astro` recognize markup comments, tags, attributes, quoted
  attribute values, Vue interpolation regions, and Astro frontmatter. Script,
  style, frontmatter, and expression bodies remain embedded text rather than
  being recursively parsed.
- `jsdoc` recognizes documentation text, `@` tags, brace-delimited type text,
  and backtick code spans. It does not validate tag grammar or type syntax.
- `regex` recognizes escapes, character classes, anchors, wildcard atoms,
  grouping punctuation, alternation, and quantifier operators. It deliberately
  does not select a regex dialect or validate group and quantifier structure.
- `proto` recognizes Protocol Buffers declarations, scalar types, comments,
  fields, values, strings and escapes, operators, and punctuation. It does not
  resolve imports, options, field types, or service signatures.

Quoted strings in the shared lexical scanners stop at a newline. Unterminated
block comments and component comments extend to end of input. These recovery
rules keep subsequent lines highlightable without claiming parser conformance.
