const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");

test "Tree-sitter Query backend conforms" {
    try helper.expect(syntax.languages.query.backend, @embedFile("corpus/query/complete.txt"), &.{ .keyword, .attribute, .constant, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" ; comment");
}
