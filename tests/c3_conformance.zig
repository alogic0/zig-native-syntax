const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");
test "C3 backend conforms" {
    try helper.expect(syntax.languages.c3.backend, @embedFile("corpus/c3/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" // comment");
}
