# Roadmap Languages 25–42 Compatibility

These dependency-free backends are bounded lexical scanners. They classify
source without validating programs, expanding macros, resolving names, or
evaluating embedded languages.

- `java`, `c-sharp`, `go`, `kotlin`, `swift`, and `objc` recognize their
  documented keyword and primitive-type sets, comments, attributes,
  identifiers, calls, numbers, strings and escapes, operators, and punctuation.
  Objective-C also classifies line-leading preprocessor directives.
- `cpp` has a separate parser-backed compatibility contract in `cpp.md`.
- `powershell`, `php`, and `ruby` recognize language keywords, comments,
  variables where prefixed, calls, values, and quoted literals. PowerShell
  here-strings, PHP heredocs, and Ruby percent literals and heredocs remain
  plain or receive only lexical scopes.
- `lua` has a separate parser-backed compatibility contract in `lua.md`.
- `asm` and `nasm` recognize common mnemonics, registers and size names,
  labels, comments, numbers, strings, operators, and punctuation. They do not
  select an instruction set or validate operands and directives.
- `astro` recognizes markup comments, tags, attributes, quoted
  attribute values and Astro frontmatter. Script, style, frontmatter, and
  expression bodies remain embedded text rather than being recursively parsed.
- `vue` has a separate composed compatibility contract in `vue.md`.
- `jsdoc` has a separate verified lexical compatibility contract in
  `jsdoc.md`.
- `regex` has a separate verified lexical compatibility contract in
  `regex.md`.
- `proto` has a separate parser-backed compatibility contract in `proto.md`.

Quoted strings in the shared lexical scanners stop at a newline. Unterminated
block comments and component comments extend to end of input. These recovery
rules keep subsequent lines highlightable without claiming parser conformance.
