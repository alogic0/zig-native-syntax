const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Git commit backend conforms" {
    try helper.expect(syntax.languages.gitcommit.backend, @embedFile("corpus/gitcommit/complete.txt"), &.{ .variable, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
