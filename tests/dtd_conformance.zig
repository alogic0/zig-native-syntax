const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "DTD backend conforms" {
    try helper.expect(syntax.languages.dtd.backend, @embedFile("corpus/dtd/complete.txt"), &.{ .keyword, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" <!-- comment");
}
