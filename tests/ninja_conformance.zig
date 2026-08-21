const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Ninja backend conforms" {
    try helper.expect(syntax.languages.ninja.backend, @embedFile("corpus/ninja/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
