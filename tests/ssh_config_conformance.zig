const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "SSH config backend conforms" {
    try helper.expect(syntax.languages.ssh_config.backend, @embedFile("corpus/ssh_config/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
