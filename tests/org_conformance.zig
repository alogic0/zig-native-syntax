const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Org Mode backend conforms" {
    try helper.expect(syntax.languages.org.backend, @embedFile("corpus/org/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
