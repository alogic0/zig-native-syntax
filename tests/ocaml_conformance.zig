const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "OCaml backend conforms" {
    try helper.expect(syntax.languages.ocaml.backend, @embedFile("corpus/ocaml/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" (* comment *)");
}
