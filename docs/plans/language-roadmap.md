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

- [x] 1. Zig
- [x] 2. Ziggy
- [x] 3. Ziggy Schema
- [x] 4. Scripty
- [x] 5. HTML
- [x] 6. XML
- [x] 7. CSS
- [x] 8. SuperHTML
- [x] 9. Markdown
- [x] 10. Bash
- [x] 11. Rust
- [x] 12. JSON
- [x] 13. Diff/patch
- [x] 14. TOML
- [x] 15. Dockerfile
- [x] 16. Python
- [x] 17. SQL
- [x] 18. C
- [x] 19. JavaScript
- [x] 20. TypeScript
- [x] 21. YAML
- [x] 22. HCL
- [x] 23. Make
- [x] 24. CMake
- [ ] 25. Java
- [ ] 26. C#
- [ ] 27. C++
- [ ] 28. Go
- [ ] 29. PowerShell
- [ ] 30. PHP
- [ ] 31. Lua
- [ ] 32. Kotlin
- [ ] 33. Ruby
- [ ] 34. Swift
- [ ] 35. Assembly
- [ ] 36. NASM
- [ ] 37. Objective-C
- [ ] 38. Vue
- [ ] 39. Astro
- [ ] 40. JSDoc
- [ ] 41. Regular expressions
- [ ] 42. Protocol Buffers
- [ ] 43. KDL
- [ ] 44. Nix
- [ ] 45. Fish
- [ ] 46. Nushell
- [ ] 47. AWK
- [ ] 48. SSH config
- [ ] 49. Git commit
- [ ] 50. Git rebase
- [ ] 51. Gettext PO
- [ ] 52. reStructuredText
- [ ] 53. LaTeX
- [ ] 54. Typst
- [ ] 55. Org Mode
- [ ] 56. DTD
- [ ] 57. E-mail
- [ ] 58. Hurl
- [ ] 59. Ninja
- [ ] 60. RPM spec
- [ ] 61. RPM Bash
- [ ] 62. GDScript
- [ ] 63. Perl
- [ ] 64. Elixir
- [ ] 65. F#
- [ ] 66. OCaml
- [ ] 67. Haskell
- [ ] 68. Gleam
- [ ] 69. Common Lisp
- [ ] 70. Scheme
- [ ] 71. Julia
- [ ] 72. Elm
- [ ] 73. PureScript
- [ ] 74. Nim
- [ ] 75. D
- [ ] 76. V
- [ ] 77. Odin
- [ ] 78. C3
- [ ] 79. SystemVerilog
- [ ] 80. LLVM IR
- [ ] 81. OpenSCAD
- [ ] 82. Nickel
- [ ] 83. Hare
- [ ] 84. Agda
- [ ] 85. Tree-sitter Query
- [ ] 86. Vimscript
- [ ] 87. Uxntal
- [ ] 88. Generic comment tags
