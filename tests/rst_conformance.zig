const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "reStructuredText backend conforms" {
    try helper.expect(syntax.languages.rst.backend, @embedFile("corpus/rst/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" .. comment");
}
