const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Nushell backend conforms" {
    try helper.expect(syntax.languages.nu.backend, @embedFile("corpus/nu/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
