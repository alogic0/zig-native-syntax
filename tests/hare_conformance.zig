const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Hare backend conforms" {
    try helper.expect(syntax.languages.hare.backend, @embedFile("corpus/hare/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
