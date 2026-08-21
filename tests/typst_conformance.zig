const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Typst backend conforms" {
    try helper.expect(syntax.languages.typst.backend, @embedFile("corpus/typst/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
