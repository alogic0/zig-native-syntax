const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "KDL backend conforms" {
    try helper.expect(syntax.languages.kdl.backend, @embedFile("corpus/kdl/complete.txt"), &.{ .variable, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\"// comment");
}
