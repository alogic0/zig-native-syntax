# Language Backend Roadmap

This checklist orders native highlighting backends by a combination of
consumer usefulness, observed popularity, implementation size, availability of
a maintained Zig syntax API, reuse of existing backends, and malformed-input
risk. It is not a promise to implement complete language grammars. Before each
unchecked item starts, confirm concrete consumer demand and document both its
lexical foundation and whether syntax structure affects classification.

Checked entries have a backend today. Markdown includes inline Markdown, while
package-owned aliases and file-type mappings do not require separate backends.
Formats and embedded syntaxes are included because Zine accepts them
as source-highlighting labels even when developer surveys do not classify them
as programming languages.

The suffix on each entry records its implementation depth on `main`:

- **parser** consumes parser or AST nodes that materially affect structural
  classification;
- **composed** delegates regions to multiple backends and states which parts
  have parser coverage;
- **tokenizer** consumes a maintained, language-specific tokenizer API without
  consuming its syntax tree;
- **dedicated scanner** uses bounded language- or format-specific scanning
  logic owned by this project;
- **configured scanner** uses the shared generic lexical engine with mostly
  declarative language configuration.

These labels describe implementation structure, not a claim of complete
grammar coverage or a strict quality ranking. Every checked backend is still
required to satisfy the shared source-preservation, range-safety, malformed
input, and deterministic-output contract. There are currently 28 parser-backed
languages, 7 partially parser-backed compositions, 4 tokenizer adapters, 14
dedicated scanners, and 42 configured scanners. This classification describes
the code that runs, not only backend metadata: Ziggy currently declares itself
`parser_backed`, but its adapter consumes only `ziggy.Tokenizer`, so it is
listed as a tokenizer here.

Quality promotion is tracked separately through `SupportLevel`. The current
configured package registry exposes 42 backends as **verified structural**
and 28 as **verified lexical**. Every entry without a verification marker
remains **experimental** even though its backend and conformance suite exist.
Promotion requires exact classification tests, representative corpus evidence,
malformed-input recovery, source preservation, and aliases that match syntax
the backend actually understands.

- [x] 1. Zig — **parser** (`std.zig.Tokenizer` and `std.zig.Ast`) — *verified structural*
- [x] 2. Ziggy — **tokenizer** (Ziggy tokenizer; AST not consumed) — *verified lexical*
- [x] 3. Ziggy Schema — **parser** (Ziggy Schema tokenizer and AST) — *verified structural*
- [x] 4. Scripty — **parser** (Scripty parser plus owned lexical classification) — *verified structural*
- [x] 5. HTML — **tokenizer** (SuperHTML HTML tokenizer; upstream AST not consumed) — *verified lexical*
- [x] 6. XML — **tokenizer** (SuperHTML XML tokenizer mode) — *verified lexical*
- [x] 7. CSS — **tokenizer** (SuperHTML CSS tokenizer plus bounded declaration context) — *verified lexical*
- [x] 8. SuperHTML — **composed** (SuperHTML markup tokenizer and parser-backed Scripty regions) — *verified structural*
- [x] 9. Markdown — **parser** (external Markdown parser) — *verified structural*
- [x] 10. Bash — **parser** (owned tolerant parser) — *verified structural*
- [x] 11. Rust — **parser** (owned tolerant parser) — *verified structural*
- [x] 12. JSON — **dedicated scanner** — *verified lexical*
- [x] 13. Diff/patch — **dedicated scanner** — *verified lexical*
- [x] 14. TOML — **dedicated scanner** — *verified lexical*
- [x] 15. Dockerfile — **composed** (Dockerfile scanner with parser-backed Bash and lexical JSON regions) — *verified structural*
- [x] 16. Python — **parser** (owned tolerant parser) — *verified structural*
- [x] 17. SQL — **dedicated scanner** — *verified lexical*
- [x] 18. C — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 19. JavaScript — **parser** (owned tolerant parser) — *verified structural*
- [x] 20. TypeScript — **parser** (shared JavaScript/TypeScript parser) — *verified structural*
- [x] 21. YAML — **dedicated scanner** — *verified lexical*
- [x] 22. HCL — **dedicated scanner** — *verified lexical*
- [x] 23. Make — **composed** (Make scanner with parser-backed Bash recipes) — *verified structural*
- [x] 24. CMake — **configured scanner** — *verified lexical*
- [x] 25. Java — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 26. C# — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 27. C++ — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 28. Go — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 29. PowerShell — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 30. PHP — **composed** (markup scanner with owned structural PHP regions) — *verified structural*
- [x] 31. Lua — **parser** (owned tolerant parser) — *verified structural*
- [x] 32. Kotlin — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 33. Ruby — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 34. Swift — **parser** (shared tolerant C-like declaration parser) — *verified structural*
- [x] 35. Assembly — **configured scanner** — *verified lexical*
- [x] 36. NASM — **configured scanner**
- [x] 37. Objective-C — **parser** (owned tolerant Objective-C declaration parser) — *verified structural*
- [x] 38. Vue — **composed** (component markup with parser-backed JavaScript regions) — *verified structural*
- [x] 39. Astro — **composed** (component markup with parser-backed JavaScript regions) — *verified structural*
- [x] 40. JSDoc — **dedicated scanner** — *verified lexical*
- [x] 41. Regular expressions — **dedicated scanner** — *verified lexical*
- [x] 42. Protocol Buffers — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 43. KDL — **dedicated scanner** — *verified lexical*
- [x] 44. Nix — **parser** (owned tolerant binding and expression parser) — *verified structural*
- [x] 45. Fish — **parser** (owned tolerant command-position parser) — *verified structural*
- [x] 46. Nushell — **parser** (owned tolerant pipeline and signature parser) — *verified structural*
- [x] 47. AWK — **parser** (owned tolerant expression and declaration parser) — *verified structural*
- [x] 48. SSH config — **dedicated scanner** — *verified lexical*
- [x] 49. Git commit — **dedicated scanner** — *verified lexical*
- [x] 50. Git rebase — **composed** (rebase scanner with parser-backed Bash exec commands) — *verified structural*
- [x] 51. Gettext PO — **dedicated scanner** — *verified lexical*
- [x] 52. reStructuredText — **dedicated scanner** — *verified lexical*
- [x] 53. LaTeX — **dedicated scanner** — *verified lexical*
- [x] 54. Typst — **composed** (markup scanner with owned code parser and math scanner) — *verified structural*
- [x] 55. Org Mode — **dedicated scanner** — *verified lexical*
- [x] 56. DTD — **configured scanner**
- [x] 57. E-mail — **dedicated scanner** — *verified lexical*
- [x] 58. Hurl — **dedicated scanner** — *verified lexical*
- [x] 59. Ninja — **dedicated scanner** — *verified lexical*
- [x] 60. RPM spec — **composed** (spec scanner with parser-backed RPM Bash scriptlets) — *verified structural*
- [x] 61. RPM Bash — **parser** (delegates to the Bash backend) — *verified structural*
- [x] 62. GDScript — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 63. Perl — **configured scanner**
- [x] 64. Elixir — **parser** (owned tolerant declaration and sigil parser) — *verified structural*
- [x] 65. F# — **configured scanner**
- [x] 66. OCaml — **configured scanner**
- [x] 67. Haskell — **configured scanner**
- [x] 68. Gleam — **configured scanner**
- [x] 69. Common Lisp — **configured scanner**
- [x] 70. Scheme — **configured scanner**
- [x] 71. Julia — **configured scanner**
- [x] 72. Elm — **configured scanner**
- [x] 73. PureScript — **configured scanner**
- [x] 74. Nim — **configured scanner**
- [x] 75. D — **configured scanner**
- [x] 76. V — **configured scanner**
- [x] 77. Odin — **configured scanner**
- [x] 78. C3 — **configured scanner**
- [x] 79. SystemVerilog — **configured scanner**
- [x] 80. LLVM IR — **dedicated scanner** — *verified lexical*
- [x] 81. OpenSCAD — **configured scanner**
- [x] 82. Nickel — **configured scanner**
- [x] 83. Hare — **configured scanner**
- [x] 84. Agda — **configured scanner**
- [x] 85. Tree-sitter Query — **parser** (owned tolerant S-expression parser) — *verified structural*
- [x] 86. Vimscript — **configured scanner**
- [x] 87. Uxntal — **configured scanner**
- [x] 88. Generic comment tags — **dedicated scanner**
- [x] 89. MLIR — **dedicated scanner** — *verified lexical*
- [x] 90. TableGen — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 91. Fortran — **configured scanner** — *verified lexical*
- [x] 92. PDLL — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 93. Windows Batch — **dedicated scanner** — *verified lexical*
- [x] 94. Starlark/Bazel — **parser** (owned tolerant declaration parser) — *verified structural*
- [x] 95. Shell session — **composed** (prompt scanner with parser-backed Bash commands) — *verified structural*
