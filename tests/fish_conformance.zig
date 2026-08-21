const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Fish backend conforms" {
    try helper.expect(syntax.languages.fish.backend, @embedFile("corpus/fish/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
