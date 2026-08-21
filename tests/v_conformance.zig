const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "V backend conforms" {
    try helper.expect(syntax.languages.v.backend, @embedFile("corpus/v/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
