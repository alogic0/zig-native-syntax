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
- [x] 25. Java
- [x] 26. C#
- [x] 27. C++
- [x] 28. Go
- [x] 29. PowerShell
- [x] 30. PHP
- [x] 31. Lua
- [x] 32. Kotlin
- [x] 33. Ruby
- [x] 34. Swift
- [x] 35. Assembly
- [x] 36. NASM
- [x] 37. Objective-C
- [x] 38. Vue
- [x] 39. Astro
- [x] 40. JSDoc
- [x] 41. Regular expressions
- [x] 42. Protocol Buffers
- [x] 43. KDL
- [x] 44. Nix
- [x] 45. Fish
- [x] 46. Nushell
- [x] 47. AWK
- [x] 48. SSH config
- [x] 49. Git commit
- [x] 50. Git rebase
- [x] 51. Gettext PO
- [x] 52. reStructuredText
- [x] 53. LaTeX
- [x] 54. Typst
- [x] 55. Org Mode
- [x] 56. DTD
- [x] 57. E-mail
- [x] 58. Hurl
- [x] 59. Ninja
- [x] 60. RPM spec
- [x] 61. RPM Bash
- [x] 62. GDScript
- [x] 63. Perl
- [x] 64. Elixir
- [x] 65. F#
- [x] 66. OCaml
- [x] 67. Haskell
- [x] 68. Gleam
- [x] 69. Common Lisp
- [x] 70. Scheme
- [x] 71. Julia
- [x] 72. Elm
- [x] 73. PureScript
- [x] 74. Nim
- [x] 75. D
- [x] 76. V
- [x] 77. Odin
- [x] 78. C3
- [x] 79. SystemVerilog
- [x] 80. LLVM IR
- [x] 81. OpenSCAD
- [x] 82. Nickel
- [x] 83. Hare
- [x] 84. Agda
- [x] 85. Tree-sitter Query
- [x] 86. Vimscript
- [x] 87. Uxntal
- [x] 88. Generic comment tags
