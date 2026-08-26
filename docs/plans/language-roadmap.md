# Language Backend Roadmap

This checklist orders native highlighting backends by a combination of
consumer usefulness, observed popularity, implementation size, availability of
a maintained Zig syntax API, reuse of existing backends, and malformed-input
risk. It is not a promise to implement complete language grammars. Before each
unchecked item starts, confirm concrete consumer demand and document both its
lexical foundation and whether syntax structure affects classification.

Checked entries have a backend today. Markdown includes inline Markdown, while
consumer-owned aliases and file-type mappings do not require separate
backends. Formats and embedded syntaxes are included because Zine accepts them
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
input, and deterministic-output contract. There are currently 9 parser-backed
languages, 1 partially parser-backed composition, 4 tokenizer adapters, 15
dedicated scanners, and 59 configured scanners. This classification describes
the code that runs, not only backend metadata: Ziggy currently declares itself
`parser_backed`, but its adapter consumes only `ziggy.Tokenizer`, so it is
listed as a tokenizer here.

Quality promotion is tracked separately through `SupportLevel`. The current
quality-first viewer registry promotes 10 backends as **verified structural**
and 6 as **verified lexical**. Every entry without a verification marker
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
- [x] 14. TOML — **dedicated scanner**
- [x] 15. Dockerfile — **dedicated scanner**
- [x] 16. Python — **dedicated scanner**
- [x] 17. SQL — **dedicated scanner**
- [x] 18. C — **dedicated scanner**
- [x] 19. JavaScript — **parser** (owned tolerant parser) — *verified structural*
- [x] 20. TypeScript — **parser** (shared JavaScript/TypeScript parser) — *verified structural*
- [x] 21. YAML — **dedicated scanner**
- [x] 22. HCL — **dedicated scanner**
- [x] 23. Make — **dedicated scanner**
- [x] 24. CMake — **configured scanner**
- [x] 25. Java — **configured scanner**
- [x] 26. C# — **configured scanner**
- [x] 27. C++ — **configured scanner**
- [x] 28. Go — **configured scanner**
- [x] 29. PowerShell — **configured scanner**
- [x] 30. PHP — **configured scanner**
- [x] 31. Lua — **configured scanner**
- [x] 32. Kotlin — **configured scanner**
- [x] 33. Ruby — **configured scanner**
- [x] 34. Swift — **configured scanner**
- [x] 35. Assembly — **configured scanner**
- [x] 36. NASM — **configured scanner**
- [x] 37. Objective-C — **configured scanner**
- [x] 38. Vue — **dedicated scanner** (shared component-markup scanner)
- [x] 39. Astro — **dedicated scanner** (shared component-markup scanner)
- [x] 40. JSDoc — **dedicated scanner**
- [x] 41. Regular expressions — **dedicated scanner**
- [x] 42. Protocol Buffers — **configured scanner**
- [x] 43. KDL — **configured scanner**
- [x] 44. Nix — **configured scanner**
- [x] 45. Fish — **configured scanner**
- [x] 46. Nushell — **configured scanner**
- [x] 47. AWK — **configured scanner**
- [x] 48. SSH config — **configured scanner**
- [x] 49. Git commit — **configured scanner**
- [x] 50. Git rebase — **configured scanner**
- [x] 51. Gettext PO — **configured scanner**
- [x] 52. reStructuredText — **configured scanner**
- [x] 53. LaTeX — **configured scanner**
- [x] 54. Typst — **configured scanner**
- [x] 55. Org Mode — **configured scanner**
- [x] 56. DTD — **configured scanner**
- [x] 57. E-mail — **configured scanner**
- [x] 58. Hurl — **configured scanner**
- [x] 59. Ninja — **configured scanner**
- [x] 60. RPM spec — **configured scanner**
- [x] 61. RPM Bash — **parser** (delegates to the Bash backend) — *verified structural*
- [x] 62. GDScript — **configured scanner**
- [x] 63. Perl — **configured scanner**
- [x] 64. Elixir — **configured scanner**
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
- [x] 80. LLVM IR — **configured scanner**
- [x] 81. OpenSCAD — **configured scanner**
- [x] 82. Nickel — **configured scanner**
- [x] 83. Hare — **configured scanner**
- [x] 84. Agda — **configured scanner**
- [x] 85. Tree-sitter Query — **configured scanner**
- [x] 86. Vimscript — **configured scanner**
- [x] 87. Uxntal — **configured scanner**
- [x] 88. Generic comment tags — **dedicated scanner**
