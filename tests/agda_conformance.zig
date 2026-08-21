const syntax = @import("native_syntax");
const helper = @import("support/extended_roadmap_conformance.zig");

test "Agda backend conforms" {
    try helper.expect(syntax.languages.agda.backend, @embedFile("corpus/agda/complete.txt"), &.{ .keyword, .type, .string, .escape, .number, .boolean, .comment }, "value = \"<&>\\q'\" -- comment");
}
