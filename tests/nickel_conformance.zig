const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Nickel backend conforms" {
    try helper.expect(syntax.languages.nickel.backend, @embedFile("corpus/nickel/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
