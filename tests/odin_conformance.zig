const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "Odin backend conforms" {
    try helper.expect(syntax.languages.odin.backend, @embedFile("corpus/odin/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
