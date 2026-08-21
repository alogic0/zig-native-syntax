const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "D backend conforms" {
    try helper.expect(syntax.languages.d.backend, @embedFile("corpus/d/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
