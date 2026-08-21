const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Hurl backend conforms" {
    try helper.expect(syntax.languages.hurl.backend, @embedFile("corpus/hurl/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" # comment");
}
