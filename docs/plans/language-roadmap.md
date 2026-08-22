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

The suffix on each entry records its implementation on `main`:

- **parser** consumes parser or AST nodes for structural classification;
- **composed** combines backends and has parser coverage only in an embedded
  language;
- **lexical** uses tokens or a bounded scanner without a syntax tree.

There are currently 8 parser-backed languages, 1 partially parser-backed
composition, and 79 lexical backends. This classification describes the code
that runs, not only backend metadata: Ziggy currently declares itself
`parser_backed`, but its adapter consumes only `ziggy.Tokenizer`, so it is
listed as lexical here.

- [x] 1. Zig — **parser**
- [x] 2. Ziggy — **lexical**
- [x] 3. Ziggy Schema — **parser**
- [x] 4. Scripty — **parser**
- [x] 5. HTML — **lexical**
- [x] 6. XML — **lexical**
- [x] 7. CSS — **lexical**
- [x] 8. SuperHTML — **composed** (HTML tokenizer and parser-backed Scripty regions)
- [x] 9. Markdown — **parser**
- [x] 10. Bash — **parser**
- [x] 11. Rust — **parser**
- [x] 12. JSON — **lexical**
- [x] 13. Diff/patch — **lexical**
- [x] 14. TOML — **lexical**
- [x] 15. Dockerfile — **lexical**
- [x] 16. Python — **lexical**
- [x] 17. SQL — **lexical**
- [x] 18. C — **lexical**
- [x] 19. JavaScript — **parser**
- [x] 20. TypeScript — **parser**
- [x] 21. YAML — **lexical**
- [x] 22. HCL — **lexical**
- [x] 23. Make — **lexical**
- [x] 24. CMake — **lexical**
- [x] 25. Java — **lexical**
- [x] 26. C# — **lexical**
- [x] 27. C++ — **lexical**
- [x] 28. Go — **lexical**
- [x] 29. PowerShell — **lexical**
- [x] 30. PHP — **lexical**
- [x] 31. Lua — **lexical**
- [x] 32. Kotlin — **lexical**
- [x] 33. Ruby — **lexical**
- [x] 34. Swift — **lexical**
- [x] 35. Assembly — **lexical**
- [x] 36. NASM — **lexical**
- [x] 37. Objective-C — **lexical**
- [x] 38. Vue — **lexical**
- [x] 39. Astro — **lexical**
- [x] 40. JSDoc — **lexical**
- [x] 41. Regular expressions — **lexical**
- [x] 42. Protocol Buffers — **lexical**
- [x] 43. KDL — **lexical**
- [x] 44. Nix — **lexical**
- [x] 45. Fish — **lexical**
- [x] 46. Nushell — **lexical**
- [x] 47. AWK — **lexical**
- [x] 48. SSH config — **lexical**
- [x] 49. Git commit — **lexical**
- [x] 50. Git rebase — **lexical**
- [x] 51. Gettext PO — **lexical**
- [x] 52. reStructuredText — **lexical**
- [x] 53. LaTeX — **lexical**
- [x] 54. Typst — **lexical**
- [x] 55. Org Mode — **lexical**
- [x] 56. DTD — **lexical**
- [x] 57. E-mail — **lexical**
- [x] 58. Hurl — **lexical**
- [x] 59. Ninja — **lexical**
- [x] 60. RPM spec — **lexical**
- [x] 61. RPM Bash — **lexical**
- [x] 62. GDScript — **lexical**
- [x] 63. Perl — **lexical**
- [x] 64. Elixir — **lexical**
- [x] 65. F# — **lexical**
- [x] 66. OCaml — **lexical**
- [x] 67. Haskell — **lexical**
- [x] 68. Gleam — **lexical**
- [x] 69. Common Lisp — **lexical**
- [x] 70. Scheme — **lexical**
- [x] 71. Julia — **lexical**
- [x] 72. Elm — **lexical**
- [x] 73. PureScript — **lexical**
- [x] 74. Nim — **lexical**
- [x] 75. D — **lexical**
- [x] 76. V — **lexical**
- [x] 77. Odin — **lexical**
- [x] 78. C3 — **lexical**
- [x] 79. SystemVerilog — **lexical**
- [x] 80. LLVM IR — **lexical**
- [x] 81. OpenSCAD — **lexical**
- [x] 82. Nickel — **lexical**
- [x] 83. Hare — **lexical**
- [x] 84. Agda — **lexical**
- [x] 85. Tree-sitter Query — **lexical**
- [x] 86. Vimscript — **lexical**
- [x] 87. Uxntal — **lexical**
- [x] 88. Generic comment tags — **lexical**
