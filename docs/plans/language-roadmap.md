# Language Backend Roadmap

This checklist orders native highlighting backends by a combination of
consumer usefulness, observed popularity, implementation size, availability of
a maintained Zig syntax API, reuse of existing backends, and malformed-input
risk. It is not a promise to implement complete language grammars. Before each
unchecked item starts, confirm concrete consumer demand and document whether
the backend is parser-backed or a bounded lexical scanner.

Checked entries have a backend today. Markdown includes inline Markdown, while
consumer-owned aliases and file-type mappings do not require separate
backends. Formats and embedded syntaxes are included because Zine accepts them
as source-highlighting labels even when developer surveys do not classify them
as programming languages.

- [x] Zig
- [x] Ziggy
- [x] Ziggy Schema
- [x] Scripty
- [x] HTML
- [x] XML
- [x] CSS
- [x] SuperHTML
- [x] Markdown
- [x] Bash
- [x] Rust
- [x] JSON
- [x] Diff/patch
- [x] TOML
- [x] Dockerfile
- [x] Python
- [ ] SQL
- [ ] C
- [ ] JavaScript
- [ ] TypeScript
- [ ] YAML
- [ ] HCL
- [ ] Make
- [ ] CMake
- [ ] Java
- [ ] C#
- [ ] C++
- [ ] Go
- [ ] PowerShell
- [ ] PHP
- [ ] Lua
- [ ] Kotlin
- [ ] Ruby
- [ ] Swift
- [ ] Assembly
- [ ] NASM
- [ ] Objective-C
- [ ] Vue
- [ ] Astro
- [ ] JSDoc
- [ ] Regular expressions
- [ ] Protocol Buffers
- [ ] KDL
- [ ] Nix
- [ ] Fish
- [ ] Nushell
- [ ] AWK
- [ ] SSH config
- [ ] Git commit
- [ ] Git rebase
- [ ] Gettext PO
- [ ] reStructuredText
- [ ] LaTeX
- [ ] Typst
- [ ] Org Mode
- [ ] DTD
- [ ] E-mail
- [ ] Hurl
- [ ] Ninja
- [ ] RPM spec
- [ ] RPM Bash
- [ ] GDScript
- [ ] Perl
- [ ] Elixir
- [ ] F#
- [ ] OCaml
- [ ] Haskell
- [ ] Gleam
- [ ] Common Lisp
- [ ] Scheme
- [ ] Julia
- [ ] Elm
- [ ] PureScript
- [ ] Nim
- [ ] D
- [ ] V
- [ ] Odin
- [ ] C3
- [ ] SystemVerilog
- [ ] LLVM IR
- [ ] OpenSCAD
- [ ] Nickel
- [ ] Hare
- [ ] Agda
- [ ] Tree-sitter Query
- [ ] Vimscript
- [ ] Uxntal
- [ ] Generic comment tags
